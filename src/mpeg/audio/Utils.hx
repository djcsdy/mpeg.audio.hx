package mpeg.audio;

class Utils {
    public static function lookupSamplesPerFrame(mpegVersion:MpegVersion) {
        return switch (mpegVersion) {
            case Version1: 1152;
            case Version2, Version25: 576;
        };
    }
}
