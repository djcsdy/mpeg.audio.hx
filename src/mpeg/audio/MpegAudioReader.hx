package mpeg.audio;

import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.Int32;
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
            [0, 32000, 64000, 96000, 128000, 160000, 192000, 224000, 256000, 288000,
                    320000, 352000, 384000, 416000, 448000, null],
            [0, 32000, 48000, 56000, 64000, 80000, 96000, 112000, 128000, 160000,
                    192000, 224000, 256000, 320000, 384000, null],
            [0, 32000, 40000, 48000, 56000, 64000, 80000, 96000, 112000, 128000,
                    160000, 192000, 224000, 256000, 320000, null]];

    static var samplingFrequencies = [44100, 48000, 32000, null];

    static var emphases = [Emphasis.None, Emphasis.RedBook, null, Emphasis.J17];

    static var slotSizeByLayerIndex = [0, 1, 1, 4];

    static var slotsByLayerIndex = [0, 12, 12, 144];

    var input:Input;
    var state:MpegAudioReaderState;

    var buffer:Bytes;
    var bufferPos:Int;

    public function new (input:Input) {
        if (input == null) {
            throw "input must not be null";
        }

        this.input = input;
        this.state = MpegAudioReaderState.Start;

        buffer = Bytes.alloc(BUFFER_SIZE);
        bufferPos = 0;
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
        try {
            do {
                do {
                    if (!bufferSpace(2)) {
                        return unknown();
                    }
                } while (readByte() != 0xff);
            } while ((readByte() & 0xf8) != 0xf8);
        } catch (eof:Eof) {
            return end();
        }

        if (bufferPos > 2) {
            state = MpegAudioReaderState.Frame;
            return unknown(bufferPos - 2);
        } else {
            return frame();
        }
    }

    function frame () {
        try {
            readBytesTo(FRAME_HEADER_SIZE);
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
            return unknown(1);
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

        var frameData = Bytes.alloc(bytes);
        frameData.blit(0, buffer, FRAME_HEADER_SIZE, bytes);

        var frame = new Frame(layer, hasCrc, bitrate, samplingFrequency, hasPadding,
                privateBit, mode, modeExtension, copyright, original, emphasis, frameData);

        state = MpegAudioReaderState.Seeking;
        return Element.Frame(frame);
    }

    function end () {
        var unknownElement = unknown();

        if (unknownElement == null) {
            state = MpegAudioReaderState.Ended;
            return Element.End;
        } else {
            state = MpegAudioReaderState.End;
            return unknownElement;
        }
    }

    function unknown (length=-1) {
        if (length == -1) {
            length = bufferPos;
        } else if (length == 0) {
            return null;
        }

        assert (length > 0 && length <= bufferPos);

        var bytes:Bytes = Bytes.alloc(length);
        bytes.blit(0, buffer, 0, length);
        var element = Element.Unknown(bytes);

        buffer.blit(0, buffer, length, bufferPos - length);
        bufferPos = length;

        return element;
    }

    inline function assert (condition:Bool) {
        if (!condition) {
            throw "MpegAudioReader internal error";
        }
    }

    inline function bufferSpace (bytes = 0) {
        return bufferPos + bytes < BUFFER_SIZE;
    }

    inline function readByte () {
        var b = input.readByte();
        buffer.set(bufferPos++, b);
        return b;
    }

    inline function readBytes (count:Int) {
        input.readBytes(buffer, bufferPos, count);
    }

    inline function readBytesTo (position:Int) {
        if (bufferPos < position) {
            input.readBytes(buffer, bufferPos, position - bufferPos);
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