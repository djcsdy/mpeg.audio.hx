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
}
