package mpeg.audio;
class Info {
    public var header(default, null):FrameHeader;

    public function new(header:FrameHeader) {
        this.header = header;
    }
}
