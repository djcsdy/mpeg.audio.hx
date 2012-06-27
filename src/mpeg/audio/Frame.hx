package mpeg.audio;

class Frame {
    public var hasCrc:Bool;
    public var hasPadding:Bool;
    public var privateBit:Bool;
    public var copyright:Bool;
    public var original:Bool;

    public function new () {
        hasCrc = false;
        hasPadding = false;
        privateBit = false;
        copyright = false;
        original = false;
    }
}
