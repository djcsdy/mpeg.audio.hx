package mpeg.audio;

import haxe.io.BytesInput;
import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.unit.TestCase;

class MpegAudioReaderTest extends TestCase {
    public function new() {
        super();
    }

    public function testConstructorRejectsNull() {
        var caught = false;
        try {
            new MpegAudioReader(null);
        } catch (e:String) {
            caught = true;
        }
        assertTrue(caught);
    }

    public function testEmptyInput() {
        var input = new InputMock();
        var reader = new MpegAudioReader(input);
        assertEquals(Element.End, reader.readNext());

        var caught = false;
        try {
            reader.readNext();
        } catch (e:Eof) {
            caught = true;
        }

        assertTrue(caught);
    }

    public function testGarbage() {
        var garbage = [0, 1, 2, 3, 4];

        var input = new InputMock();
        input.enqueueIterable(garbage);

        var reader = new MpegAudioReader(input);

        var result:Array<Int> = [];
        while (true) {
            switch (reader.readNext()) {
                case Unknown(bytes):
                for (i in 0...bytes.length) {
                    result.push(bytes.get(i));
                }

                case End:
                break;

                default:
                throw "Expected 'Unknown' or 'End'";
            }
        }

        assertSequenceEquals(garbage, result);
    }

    public function testTruncatedFrame() {
        var bytes = [0xff, 0xfa, 0x90, 0x40, 0x01, 0x02, 0x03];

        var input = new InputMock();
        input.enqueueIterable(bytes);

        var reader = new MpegAudioReader(input);

        var result:Array<Int> = [];
        while (true) {
            switch (reader.readNext()) {
                case Unknown(bytes):
                for (i in 0...bytes.length) {
                    result.push(bytes.get(i));
                }

                case End:
                break;

                default:
                throw "Expected 'Unknown' or 'End'";
            }
        }

        assertSequenceEquals(bytes, result);
    }

    public function testSingleFrame() {
        for (test in [
            {
                start: 0x343,
                length: 0x343,
                hasPadding: false,
                modeExtension: 0
            },
            {
                start: 0x686,
                length: 0x344,
                hasPadding: true,
                modeExtension: 2
            }
        ]) {
            var bytes = Bytes.alloc(test.length);
            bytes.blit(0, haxe.Resource.getBytes("acsloop-lame.mp3"), test.start, test.length);

            var input = new BytesInput(bytes);

            var reader = new MpegAudioReader(input);

            var element = reader.readNext();
            switch (element) {
                case Frame(frame):
                assertEquals(Layer.Layer3, frame.header.layer);
                assertTrue(frame.header.hasCrc);
                assertEquals(256000, frame.header.bitrate);
                assertEquals(44100, frame.header.samplingFrequency);
                assertEquals(test.hasPadding, frame.header.hasPadding);
                assertFalse(frame.header.privateBit);
                assertEquals(Mode.JointStereo, frame.header.mode);
                assertEquals(test.modeExtension, frame.header.modeExtension);
                assertFalse(frame.header.copyright);
                assertTrue(frame.header.original);
                assertEquals(Emphasis.None, frame.header.emphasis);
                assertEquals(test.length, frame.frameData.length);

                default:
                throw "Expected 'Frame', but saw '" + element + "'";
            }

            assertEquals(Element.End, reader.readNext());
        }
    }

    public function testSingleFrameModifiedMetadata() {
        var bytes = Bytes.alloc(0x343);

        for (emphasis in [{i: 0x1, expected: Emphasis.RedBook}, {i: 0x3, expected: Emphasis.J17}]) {
            bytes.blit(0, haxe.Resource.getBytes("acsloop-lame.mp3"), 0x343, 0x343);

            bytes.set(3, bytes.get(3) & 0xf0 | 0x08 | emphasis.i);

            var input = new BytesInput(bytes);

            var reader = new MpegAudioReader(input);

            var element = reader.readNext();
            switch (element) {
                case Frame(frame):
                assertEquals(Layer.Layer3, frame.header.layer);
                assertTrue(frame.header.hasCrc);
                assertEquals(256000, frame.header.bitrate);
                assertEquals(44100, frame.header.samplingFrequency);
                assertFalse(frame.header.hasPadding);
                assertFalse(frame.header.privateBit);
                assertEquals(Mode.JointStereo, frame.header.mode);
                assertEquals(0, frame.header.modeExtension);
                assertTrue(frame.header.copyright);
                assertFalse(frame.header.original);
                assertEquals(emphasis.expected, frame.header.emphasis);
                assertEquals(0x343, frame.frameData.length);

                default:
                throw "Expected 'Frame', but saw '" + element + "'";
            }

            assertEquals(Element.End, reader.readNext());
        }
    }

    public function testSingleFrameWithInvalidHeader() {
        var inputBytes = Bytes.alloc(0x343);

        for (invalidate in [
        function(bytes:Bytes) {
            // Invalid Layer
            bytes.set(1, bytes.get(1) & 0xf9);
        },
        function(bytes:Bytes) {
            // Invalid bit-rate
            bytes.set(2, bytes.get(2) | 0xf0);
        },
        function(bytes:Bytes) {
            // Invalid sampling frequency
            bytes.set(2, bytes.get(2) | 0x0c);
        },
        function(bytes:Bytes) {
            // Invalid emphasis
            bytes.set(3, bytes.get(3) & 0xfc | 0x02);
        }
        ]) {
            inputBytes.blit(0, haxe.Resource.getBytes("acsloop-lame.mp3"), 0x343, 0x343);

            invalidate(inputBytes);

            var input = new BytesInput(inputBytes);

            var reader = new MpegAudioReader(input);

            var result:Array<Int> = [];

            while (true) {
                var element = reader.readNext();
                switch (element) {
                    case Unknown(bytes):
                    for (i in 0...bytes.length) {
                        result.push(bytes.get(i));
                    }

                    case End:
                    break;

                    default:
                    throw "Expected 'Unknown' or 'End', but saw '" + element + "'";
                }
            }

            assertEquals(inputBytes.length, result.length);

            for (i in 0...result.length) {
                assertEquals(inputBytes.get(i), result[i]);
            }
        }
    }

    public function testSingleFrameWithGarbagePrepended() {
        var inputBytes = Bytes.alloc(0x343);
        inputBytes.blit(0, haxe.Resource.getBytes("acsloop-lame.mp3"), 0x343, 0x343);

        for (garbage in [
            [0xff],
            [0xff, 0xfb],
            [0x00],
            [0x12, 0x23, 0x34]
        ]) {
            var input = new InputMock();
            input.enqueueIterable(garbage);
            input.enqueueBytes(inputBytes);

            var reader = new MpegAudioReader(input);

            var resultGarbage:Array<Int> = [];

            var element = reader.readNext();
            switch (element) {
                case Unknown(bytes):
                for (i in 0...bytes.length) {
                    resultGarbage.push(bytes.get(i));
                }

                default:
                throw "Expected 'Unknown', but saw '" + element + "'";
            }

            var resultFrame:Frame = null;

            while (resultFrame == null) {
                element = reader.readNext();
                switch (element) {
                    case Unknown(bytes):
                    for (i in 0...bytes.length) {
                        resultGarbage.push(bytes.get(i));
                    }

                    case Frame(frame):
                    resultFrame = frame;

                    default:
                    throw "Expected 'Unknown' or 'Frame', but saw '" + element + "'";
                }
            }

            assertEquals(Element.End, reader.readNext());

            assertSequenceEquals(garbage, resultGarbage);

            assertEquals(Layer.Layer3, resultFrame.header.layer);
            assertTrue(resultFrame.header.hasCrc);
            assertEquals(256000, resultFrame.header.bitrate);
            assertEquals(44100, resultFrame.header.samplingFrequency);
            assertFalse(resultFrame.header.hasPadding);
            assertFalse(resultFrame.header.privateBit);
            assertEquals(Mode.JointStereo, resultFrame.header.mode);
            assertEquals(0, resultFrame.header.modeExtension);
            assertFalse(resultFrame.header.copyright);
            assertTrue(resultFrame.header.original);
            assertEquals(Emphasis.None, resultFrame.header.emphasis);
            assertEquals(0x343, resultFrame.frameData.length);
        }
    }

    public function testSingleFrameWithGarbageAppended() {
        var inputBytes = Bytes.alloc(0x343);
        inputBytes.blit(0, haxe.Resource.getBytes("acsloop-lame.mp3"), 0x343, 0x343);

        for (garbage in [
            [0xff],
            [0xff, 0xfb],
            [0x00],
            [0x12, 0x23, 0x34]
        ]) {
            var input = new InputMock();
            input.enqueueBytes(inputBytes);
            input.enqueueIterable(garbage);

            var reader = new MpegAudioReader(input);

            var resultFrame:Frame = null;

            var element = reader.readNext();
            switch (element) {
                case Frame(frame):
                resultFrame = frame;

                default:
                throw "Expected 'Frame', but saw '" + element + "'";
            }

            var resultGarbage:Array<Int> = [];

            while (true) {
                element = reader.readNext();
                switch (element) {
                    case Unknown(bytes):
                    for (i in 0...bytes.length) {
                        resultGarbage.push(bytes.get(i));
                    }

                    case End:
                    break;

                    default:
                    throw "Expected 'Unknown' or 'End', but saw '" + element + "'";
                }
            }

            assertEquals(Layer.Layer3, resultFrame.header.layer);
            assertTrue(resultFrame.header.hasCrc);
            assertEquals(256000, resultFrame.header.bitrate);
            assertEquals(44100, resultFrame.header.samplingFrequency);
            assertFalse(resultFrame.header.hasPadding);
            assertFalse(resultFrame.header.privateBit);
            assertEquals(Mode.JointStereo, resultFrame.header.mode);
            assertEquals(0, resultFrame.header.modeExtension);
            assertFalse(resultFrame.header.copyright);
            assertTrue(resultFrame.header.original);
            assertEquals(Emphasis.None, resultFrame.header.emphasis);
            assertEquals(0x343, resultFrame.frameData.length);

            assertSequenceEquals(garbage, resultGarbage);
        }
    }

    public function testTwoSuccessiveFrames() {
        var bytes = Bytes.alloc(0x687);
        bytes.blit(0, haxe.Resource.getBytes("acsloop-lame.mp3"), 0x343, 0x687);

        var input = new BytesInput(bytes);

        var reader = new MpegAudioReader(input);

        for (expectedFrame in [
            {
                length: 0x343,
                hasPadding: false,
                modeExtension: 0
            },
            {
                length: 0x344,
                hasPadding: true,
                modeExtension: 2
            }
        ]) {
            var element = reader.readNext();
            switch (element) {
                case Frame(frame):
                assertEquals(Layer.Layer3, frame.header.layer);
                assertTrue(frame.header.hasCrc);
                assertEquals(256000, frame.header.bitrate);
                assertEquals(44100, frame.header.samplingFrequency);
                assertEquals(expectedFrame.hasPadding, frame.header.hasPadding);
                assertFalse(frame.header.privateBit);
                assertEquals(Mode.JointStereo, frame.header.mode);
                assertEquals(expectedFrame.modeExtension, frame.header.modeExtension);
                assertFalse(frame.header.copyright);
                assertTrue(frame.header.original);
                assertEquals(Emphasis.None, frame.header.emphasis);
                assertEquals(expectedFrame.length, frame.frameData.length);

                default:
                throw "Expected 'Frame', but saw '" + element + "'";
            }
        }

        assertEquals(Element.End, reader.readNext());
    }

    public function testWholeFileExcludingInfoTag() {
        var resourceBytes = haxe.Resource.getBytes("acsloop-lame.mp3");
        var inputBytes = Bytes.alloc(resourceBytes.length - 0x343);
        inputBytes.blit(0, resourceBytes, 0x343, inputBytes.length);

        var input = new BytesInput(inputBytes);

        var reader = new MpegAudioReader(input);

        var frameCount = 0;
        var totalSizeBytes = 0;

        while (true) {
            var element = reader.readNext();
            switch (element) {
                case Frame(frame):
                assertEquals(Layer.Layer3, frame.header.layer);
                assertTrue(frame.header.hasCrc);
                assertEquals(256000, frame.header.bitrate);
                assertEquals(44100, frame.header.samplingFrequency);
                assertFalse(frame.header.privateBit);
                assertEquals(Mode.JointStereo, frame.header.mode);
                assertTrue(frame.header.modeExtension == 0 || frame.header.modeExtension == 2);
                assertFalse(frame.header.copyright);
                assertTrue(frame.header.original);
                assertEquals(Emphasis.None, frame.header.emphasis);
                assertEquals(if (frame.header.hasPadding) 0x344 else 0x343, frame.frameData.length);
                ++frameCount;
                totalSizeBytes += frame.frameData.length;

                case End:
                break;

                default:
                throw "Expected 'Frame' or 'End', but saw '" + element + "'";
            }
        }

        assertEquals(247, frameCount);
        assertEquals(inputBytes.length, totalSizeBytes);
    }

    public function testInfoTag() {
        var resourceBytes = haxe.Resource.getBytes("acsloop-lame.mp3");
        var inputBytes = Bytes.alloc(0x343);
        inputBytes.blit(0, resourceBytes, 0, 0x343);

        var input = new BytesInput(inputBytes);

        var reader = new MpegAudioReader(input);

        var element = reader.readNext();
        switch (element) {
            case Info(info):
            assertEquals(Layer.Layer3, info.header.layer);
            assertTrue(info.header.hasCrc);
            assertEquals(256000, info.header.bitrate);
            assertEquals(44100, info.header.samplingFrequency);
            assertFalse(info.header.hasPadding);
            assertFalse(info.header.privateBit);
            assertEquals(Mode.JointStereo, info.header.mode);
            assertEquals(2, info.header.modeExtension);
            assertFalse(info.header.copyright);
            assertTrue(info.header.original);
            assertEquals(Emphasis.None, info.header.emphasis);
            assertEquals(0x24, info.infoStartIndex);
            assertEquals(0x343, info.frameData.length);

            default:
            throw "Expected 'Info', but saw '" + element + "'";
        }

        element = reader.readNext();
        switch (element) {
            case GaplessInfo(encoderDelay, endPadding):
            assertEquals(576, encoderDelay);
            assertEquals(1728, endPadding);

            default:
            throw "Expected 'GaplessInfo', but saw '" + element + "'";
        }

        assertEquals(Element.End, reader.readNext());
    }

    public function testWholeFile() {
        var inputBytes = haxe.Resource.getBytes("acsloop-lame.mp3");

        var input = new BytesInput(inputBytes);

        var reader = new MpegAudioReader(input);

        var frameCount = 0;
        var totalSizeBytes = 0;

        var element = reader.readNext();
        switch (element) {
            case Info(info):
            assertEquals(Layer.Layer3, info.header.layer);
            assertTrue(info.header.hasCrc);
            assertEquals(256000, info.header.bitrate);
            assertEquals(44100, info.header.samplingFrequency);
            assertFalse(info.header.hasPadding);
            assertFalse(info.header.privateBit);
            assertEquals(Mode.JointStereo, info.header.mode);
            assertEquals(2, info.header.modeExtension);
            assertFalse(info.header.copyright);
            assertTrue(info.header.original);
            assertEquals(Emphasis.None, info.header.emphasis);
            assertEquals(0x24, info.infoStartIndex);
            assertEquals(0x343, info.frameData.length);
            totalSizeBytes += info.frameData.length;

            default:
            throw "Expected 'Info', but saw '" + element + "'";
        }

        element = reader.readNext();
        switch (element) {
            case GaplessInfo(encoderDelay, endPadding):
            assertEquals(576, encoderDelay);
            assertEquals(1728, endPadding);

            default:
            throw "Expected 'GaplessInfo', but saw '" + element + "'";
        }

        while (true) {
            element = reader.readNext();
            switch (element) {
                case Frame(frame):
                assertEquals(Layer.Layer3, frame.header.layer);
                assertTrue(frame.header.hasCrc);
                assertEquals(256000, frame.header.bitrate);
                assertEquals(44100, frame.header.samplingFrequency);
                assertFalse(frame.header.privateBit);
                assertEquals(Mode.JointStereo, frame.header.mode);
                assertTrue(frame.header.modeExtension == 0 || frame.header.modeExtension == 2);
                assertFalse(frame.header.copyright);
                assertTrue(frame.header.original);
                assertEquals(Emphasis.None, frame.header.emphasis);
                assertEquals(if (frame.header.hasPadding) 0x344 else 0x343, frame.frameData.length);
                ++frameCount;
                totalSizeBytes += frame.frameData.length;

                case End:
                break;

                default:
                throw "Expected 'Frame' or 'End', but saw '" + element + "'";
            }
        }

        assertEquals(247, frameCount);
        assertEquals(inputBytes.length, totalSizeBytes);
    }

    function assertSequenceEquals<T>(expected:Iterable<T>, actual:Iterable<T>) {
        var expectedIterator = expected.iterator();
        var actualIterator = actual.iterator();

        while (expectedIterator.hasNext() && actualIterator.hasNext()) {
            assertEquals(expectedIterator.next(), actualIterator.next());
        }

        assertFalse(expectedIterator.hasNext());
        assertFalse(actualIterator.hasNext());
    }
}
