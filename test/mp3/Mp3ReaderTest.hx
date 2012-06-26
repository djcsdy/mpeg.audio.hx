package mp3;

import haxe.unit.TestCase;

class Mp3ReaderTest extends TestCase {
    public function new () {
        super();
    }

    public function testConstructorRejectsNull () {
        var caught = false;
        try {
            new Mp3Reader(null);
        } catch (e:String) {
            caught = true;
        }
        assertTrue(caught);
    }
}
