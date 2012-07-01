package mpeg.audio;

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
        input.enqueueBytes(garbage);

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
