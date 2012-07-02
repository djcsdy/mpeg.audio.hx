package mpeg.audio;

import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.unit.TestCase;

class MpegAudioReaderTest extends TestCase {
    public function new () {
        super();
    }

    public function testConstructorRejectsNull () {
        var caught = false;
        try {
            new MpegAudioReader(null);
        } catch (e:String) {
            caught = true;
        }
        assertTrue(caught);
    }

    public function testEmptyInput () {
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

    public function testGarbage () {
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

    public function testTruncatedFrame () {
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

    public function testSingleFrame () {
        var bytes:Bytes = Bytes.alloc(0x343);
        bytes.blit(0, haxe.Resource.getBytes("acsloop-lame.mp3"), 0x343, 0x343);

        var input = new InputMock();
        input.enqueueBytes(bytes);

        var reader = new MpegAudioReader(input);

        var element = reader.readNext();
        switch (element) {
            case Frame(frame):
            assertEquals(Layer.Layer3, frame.layer);
            assertTrue(frame.hasCrc);
            assertEquals(256000, frame.bitrate);
            assertEquals(44100, frame.samplingFrequency);
            assertEquals(false, frame.hasPadding);
            assertEquals(false, frame.privateBit);
            assertEquals(Mode.JointStereo, frame.mode);
            assertEquals(0, frame.modeExtension);
            assertEquals(false, frame.copyright);
            assertEquals(true, frame.original);
            assertEquals(Emphasis.None, frame.emphasis);
            assertEquals(0x343, frame.frameData.length);

            default:
            throw "Expected 'Frame', but saw '" + element + "'";
        }

        assertEquals(Element.End, reader.readNext());
    }

    public function testSingleFrameModifiedMetadata () {
        var bytes:Bytes = Bytes.alloc(0x343);
        bytes.blit(0, haxe.Resource.getBytes("acsloop-lame.mp3"), 0x343, 0x343);

        bytes.set(3, bytes.get(3) & 0xf0 | 0x09);

        var input = new InputMock();
        input.enqueueBytes(bytes);

        var reader = new MpegAudioReader(input);

        var element = reader.readNext();
        switch (element) {
            case Frame(frame):
            assertEquals(Layer.Layer3, frame.layer);
            assertTrue(frame.hasCrc);
            assertEquals(256000, frame.bitrate);
            assertEquals(44100, frame.samplingFrequency);
            assertEquals(false, frame.hasPadding);
            assertEquals(false, frame.privateBit);
            assertEquals(Mode.JointStereo, frame.mode);
            assertEquals(0, frame.modeExtension);
            assertEquals(true, frame.copyright);
            assertEquals(false, frame.original);
            assertEquals(Emphasis.RedBook, frame.emphasis);
            assertEquals(0x343, frame.frameData.length);

            default:
            throw "Expected 'Frame', but saw '" + element + "'";
        }

        assertEquals(Element.End, reader.readNext());
    }

    function assertSequenceEquals<T> (expected:Iterable<T>, actual:Iterable<T>) {
        var expectedIterator = expected.iterator();
        var actualIterator = actual.iterator();

        while (expectedIterator.hasNext() && actualIterator.hasNext()) {
            assertEquals(expectedIterator.next(), actualIterator.next());
        }

        assertFalse(expectedIterator.hasNext());
        assertFalse(actualIterator.hasNext());
    }
}
