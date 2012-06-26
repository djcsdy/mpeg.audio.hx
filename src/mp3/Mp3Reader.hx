package mp3;

import haxe.io.Eof;
import haxe.Int32;
import haxe.io.Input;

class Mp3Reader {
    var input:Input;
    var atStart:Bool;
    var atEnd:Bool;

    public function new (input:Input) {
        if (input == null) {
            throw "input must not be null";
        }

        this.input = input;
        atStart = true;
        atEnd = false;
    }

    public function readMp3 () {
        if (!atStart) {
            throw "Cannot combine calls to readElement and readMp3";
        }

        var frames:Array<Mp3Frame> = [];

        while (true) {
            var element = readElement();

            switch (element) {
                case Frame(frame):
                frames.push(frame);

                case End:
                break;
            }
        }

        var mp3 = new Mp3();
        mp3.frames = frames;

        return mp3;
    }

    public function readElement () {
        if (atEnd) {
            throw new Eof();
        }

        try {
            var b = 0;

            do {
                while (input.readByte() != 0xff) {}
            } while ((b = input.readByte()) & 0xf8 != 0xf8);

            var layerIndex = (b >> 1) & 0x3;
            var hasCrc = b & 1 == 1;

            b = input.readByte();

            var bitrateIndex = (b >> 4) & 0xf;
            var samplingFrequencyIndex = (b >> 2) & 0x2;
            var hasPadding = (b >> 1) & 1 == 1;
            var privateBit = b & 1 == 1;

            b = input.readByte();
            var modeIndex = (b >> 6) & 0x2;
            var modeExtensionIndex = (b >> 4) & 0x2;
            var copyright = (b >> 3) & 1 == 1;
            var original = (b >> 2) & 1 == 1;
            var emphasisIndex = b & 0x2;

            var frame = new Mp3Frame();
            frame.hasCrc = hasCrc;
            frame.hasPadding = hasPadding;
            frame.privateBit = privateBit;
            frame.copyright = copyright;
            frame.original = original;

            return Mp3Element.Frame(frame);
        } catch (eof:Eof) {
            return Mp3Element.End;
        }
    }
}
