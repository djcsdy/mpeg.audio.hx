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

    static var layers = [null, Layer.Layer3, Layer.Layer2, Layer.Layer1];

    static var bitrates = [
            [null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null],
            [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448, null],
            [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, null],
            [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, null]];

    static var samplingFrequencies = [44100, 48000, 32000, null];

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

            case Frame(frame):
            state = MpegAudioReaderState.Seeking;
            return Element.Frame(frame);

            case InvalidFrame():
            state = MpegAudioReaderState.Seeking;
            return unknown();

            case End:
            throw new Eof();
        }
    }

    function seek () {
        try {
            var b = 0;

            do {
                do {
                    if (!bufferSpace(2)) {
                        return unknown();
                    }
                } while (readByte() != 0xff);
            } while ((b = readByte() & 0xf8) != 0xf8);

            var unknownElement = unknown(-2);

            var layerIndex = (b >> 1) & 0x3;
            var hasCrc = b & 1 == 1;

            b = readByte();

            var bitrateIndex = (b >> 4) & 0xf;
            var samplingFrequencyIndex = (b >> 2) & 0x2;
            var hasPadding = (b >> 1) & 1 == 1;
            var privateBit = b & 1 == 1;

            b = readByte();
            var modeIndex = (b >> 6) & 0x2;
            var modeExtensionIndex = (b >> 4) & 0x2;
            var copyright = (b >> 3) & 1 == 1;
            var original = (b >> 2) & 1 == 1;
            var emphasisIndex = b & 0x2;

            var layer = layers[layerIndex];
            var bitrate = bitrates[layerIndex][bitrateIndex];
            var samplingFrequency = samplingFrequencies[samplingFrequencyIndex];

            if (layer == null || bitrate == null || samplingFrequency == null) {
                state = MpegAudioReaderState.InvalidFrame;
                return unknownElement;
            }

            // TODO

            var frame = new Frame(layer, hasCrc, bitrate, samplingFrequency,
                    hasPadding, privateBit, copyright, original);

            if (unknownElement == null) {
                state = MpegAudioReaderState.Seeking;
                return Element.Frame(frame);
            } else {
                state = MpegAudioReaderState.Frame(frame);
                return unknownElement;
            }
        } catch (eof:Eof) {
            return Element.End;
        }
    }

    function unknown (offset=0) {
        if (offset > 0 || -offset > bufferPos) {
            throw "MpegAudioReader internal error";
        }

        var length = bufferPos + offset;

        if (length == 0) {
            return null;
        }

        var bytes:Bytes = Bytes.alloc(length);
        bytes.blit(0, buffer, 0, length);
        var element = Element.Unknown(bytes);

        buffer.blit(0, buffer, length, -offset);
        bufferPos = -offset;

        return element;
    }

    inline function bufferSpace (bytes = 0) {
        return bufferPos + bytes < BUFFER_SIZE;
    }

    inline function readByte () {
        var b = input.readByte();
        buffer.set(bufferPos++, b);
        return b;
    }

    inline function byte () {
        return buffer.get(bufferPos);
    }
}

private enum MpegAudioReaderState {
    Start;
    Seeking;
    Frame(frame:Frame);
    InvalidFrame;
    End;
}