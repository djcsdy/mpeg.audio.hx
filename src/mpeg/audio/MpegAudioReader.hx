package mpeg.audio;

import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.io.Input;

class MpegAudioReader {
    // The theoretical absolute maximum frame size is 2881 bytes
    // (MPEG 2.5 Layer II 160Kb/s, with a padding slot).
    //
    // This is the next-largest power-of-two.
    static inline var BUFFER_SIZE = 4096;

    static inline var FRAME_HEADER_SIZE = 4;

    static var layers = [null, Layer.Layer3, Layer.Layer2, Layer.Layer1];

    static var bitrates = [
            [null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null],
            [0, 32000, 40000, 48000, 56000, 64000, 80000, 96000, 112000, 128000,
            160000, 192000, 224000, 256000, 320000, null],
            [0, 32000, 48000, 56000, 64000, 80000, 96000, 112000, 128000, 160000,
                    192000, 224000, 256000, 320000, 384000, null],
            [0, 32000, 64000, 96000, 128000, 160000, 192000, 224000, 256000, 288000,
                    320000, 352000, 384000, 416000, 448000, null]];

    static var samplingFrequencies = [44100, 48000, 32000, null];

    static var emphases = [Emphasis.None, Emphasis.RedBook, null, Emphasis.J17];

    static var slotSizeByLayerIndex = [0, 1, 1, 4];

    static var slotsByLayerIndex = [0, 144, 12, 12];

    var input:Input;
    var state:MpegAudioReaderState;

    var buffer:Bytes;
    var bufferCursor:Int;
    var bufferLength:Int;

    public function new (input:Input) {
        if (input == null) {
            throw "input must not be null";
        }

        this.input = input;
        this.state = MpegAudioReaderState.Start;

        buffer = Bytes.alloc(BUFFER_SIZE);
        bufferCursor = 0;
        bufferLength = 0;
    }

    public function readAll () {
        if (state != MpegAudioReaderState.Start) {
            throw "Cannot combine calls to readNext and readAll";
        }

        var frames:Array<Frame> = [];

        while (true) {
            var element = readNext();

            switch (element) {
                case Frame(frame):
                frames.push(frame);

                case Unknown(bytes):
                // TODO

                case End:
                break;
            }
        }

        var audio = new MpegAudio();
        audio.frames = frames;

        return audio;
    }

    public function readNext () {
        switch (state) {
            case Start, Seeking:
            return seek();

            case Frame:
            return frame();

            case End:
            return end();

            case Ended:
            throw new Eof();
        }
    }

    function seek () {
        bufferCursor = 0;

        try {
            do {
                do {
                    if (!bufferSpace(2)) {
                        return yieldUnknown();
                    }
                } while (readByte() != 0xff);
            } while ((readByte() & 0xf8) != 0xf8);
        } catch (eof:Eof) {
            return end();
        }

        if (bufferCursor > 2) {
            state = MpegAudioReaderState.Frame;
            return yieldUnknown(bufferCursor - 2);
        } else {
            return frame();
        }
    }

    function frame () {
        try {
            readAheadBytesTo(FRAME_HEADER_SIZE);
        } catch (eof:Eof) {
            return end();
        }

        var b = buffer.get(1);
        var layerIndex = (b >> 1) & 0x3;
        var hasCrc = b & 1 == 1;

        b = buffer.get(2);
        var bitrateIndex = (b >> 4) & 0xf;
        var samplingFrequencyIndex = (b >> 2) & 0x2;
        var hasPadding = (b >> 1) & 1 == 1;
        var privateBit = b & 1 == 1;

        b = buffer.get(3);
        var mode = (b >> 6) & 0x2;
        var modeExtension = (b >> 4) & 0x2;
        var copyright = (b >> 3) & 1 == 1;
        var original = (b >> 2) & 1 == 1;
        var emphasisIndex = b & 0x2;

        var layer = layers[layerIndex];
        var bitrate = bitrates[layerIndex][bitrateIndex];
        var samplingFrequency = samplingFrequencies[samplingFrequencyIndex];
        var emphasis = emphases[emphasisIndex];

        if (layer == null || bitrate == null || samplingFrequency == null
                || emphasis == null) {
            // This isn't a valid frame.
            // Seek for another frame starting from the byte after the bogus syncword.
            state = MpegAudioReaderState.Seeking;
            return yieldUnknown(1);
        }

        // TODO handle free-format bitrate.

        var slots = Math.floor(slotsByLayerIndex[layerIndex] * bitrate / samplingFrequency)
                + if (hasPadding) 1 else 0;

        var bytes = slots * slotSizeByLayerIndex[layerIndex]
                + if (hasCrc) 2 else 0;

        try {
            readBytes(bytes);
        } catch (eof:Eof) {
            return end();
        }

        var frameData = yieldBytes();

        var frame = new Frame(layer, hasCrc, bitrate, samplingFrequency, hasPadding,
                privateBit, mode, modeExtension, copyright, original, emphasis, frameData);

        state = MpegAudioReaderState.Seeking;
        return Element.Frame(frame);
    }

    function end () {
        var unknownElement = yieldUnknown(bufferLength);

        if (unknownElement == null) {
            state = MpegAudioReaderState.Ended;
            return Element.End;
        } else {
            state = MpegAudioReaderState.End;
            return unknownElement;
        }
    }

    function yieldUnknown (length=-1) {
        if (length == -1) {
            length = bufferCursor;
        }

        if (length == 0) {
            return null;
        }

        return Element.Unknown(yieldBytes(length));
    }

    function yieldBytes (length=-1) {
        if (length == -1) {
            length = bufferCursor;
        } else if (length == 0) {
            return Bytes.alloc(0);
        }

        assert(length > 0 && length <= bufferLength);

        var bytes:Bytes = Bytes.alloc(length);
        bytes.blit(0, buffer, 0, length);

        buffer.blit(0, buffer, length, bufferLength - length);

        bufferLength -= length;
        bufferCursor -= length;

        return bytes;
    }

    inline function assert (condition:Bool) {
        if (!condition) {
            throw "MpegAudioReader internal error";
        }
    }

    inline function bufferSpace (bytes = 0) {
        return bufferCursor + bytes < BUFFER_SIZE;
    }

    inline function readByte (position:Int=-1) {
        if (position == -1) {
            position = bufferCursor;
        }

        readAheadBytesTo(position);

        bufferCursor = position + 1;

        return buffer.get(position);
    }

    inline function readBytes (count:Int) {
        readAheadBytesTo(bufferCursor + count);
        bufferCursor += count;
    }

    inline function readAheadBytesTo (position:Int) {
        assert (position >= 0 && position < BUFFER_SIZE);

        while (bufferLength <= position) {
            buffer.set(bufferLength, input.readByte());
            ++bufferLength;
        }
    }
}

private enum MpegAudioReaderState {
    Start;
    Seeking;
    Frame;
    End;
    Ended;
}