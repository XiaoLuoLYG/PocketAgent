import localUnitTest from './LocalUnit.test';
import a2uiParserTest from './A2uiParser.test';

export default function testsuite() {
  localUnitTest();
  a2uiParserTest();
}
