package mpeg.audio;

class Frame {
    public var layer(default, null):Layer;
    public var hasCrc(default, null):Bool;
    public var bitrate(default, null):Int;
    public var samplingFrequency(default, null):Int;
    public var hasPadding(default, null):Bool;
    public var privateBit(default, null):Bool;
    public var copyright(default, null):Bool;
    public var original(default, null):Bool;

    public function new(layer:Layer, hasCrc:Bool, bitrate:Int, samplingFrequency:Int, hasPadding:Bool,
                        privateBit:Bool, copyright:Bool, original:Bool) {
        this.layer = layer;
        this.hasCrc = hasCrc;
        this.bitrate = bitrate;
        this.samplingFrequency = samplingFrequency;
        this.hasPadding = hasPadding;
        this.privateBit = privateBit;
        this.copyright = copyright;
        this.original = original;
    }
}
