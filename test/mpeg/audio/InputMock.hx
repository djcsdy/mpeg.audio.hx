package mpeg.audio;

import haxe.io.Eof;
import haxe.io.Input;

class InputMock extends Input {
    public var onReadByte:Void->Int;

    public function new() {
        onReadByte = function():Int { throw new Eof(); return 0; };
    }

    override public function readByte() {
        return onReadByte();
    }
}
