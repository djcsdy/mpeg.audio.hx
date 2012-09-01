package mpeg.audio;

import haxe.io.Bytes;
import haxe.unit.TestCase;

class UtilsTest extends TestCase {
    public function new() {
        super();
    }

    public function testCalculateAudioLengthSamples() {
        var mpegAudio = new MpegAudio(
                [
                    new Frame(
                            new FrameHeader(MpegVersion.Version1, Layer.Layer3, true, 128000, 44100, false, false,
                                    Mode.JointStereo, 0, false, false, Emphasis.None),
                            Bytes.alloc(0)),
                    new Frame(
                            new FrameHeader(MpegVersion.Version2, Layer.Layer1, true, 32000, 12000, false, false,
                                    Mode.JointStereo, 0, false, false, Emphasis.None),
                            Bytes.alloc(0)),
                    new Frame(
                            new FrameHeader(MpegVersion.Version25, Layer.Layer2, true, 24000, 11025, false, false,
                                    Mode.JointStereo, 0, false, false, Emphasis.None),
                            Bytes.alloc(0)),
                    new Frame(
                            new FrameHeader(MpegVersion.Version2, Layer.Layer2, true, 24000, 22050, false, false,
                                    Mode.JointStereo, 0, false, false, Emphasis.None),
                            Bytes.alloc(0)),
                    new Frame(
                            new FrameHeader(MpegVersion.Version25, Layer.Layer3, true, 128000, 11025, false, false,
                                    Mode.JointStereo, 0, false, false, Emphasis.None),
                            Bytes.alloc(0))
                ],
                123, 456);

        assertEquals(3837, Utils.calculateAudioLengthSamples(mpegAudio));
    }
}
