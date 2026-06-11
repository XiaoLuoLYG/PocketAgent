import abilityTest from './Ability.test';
import sharedUnitTests from '../../../test/List.test';

export default function testsuite() {
  abilityTest();
  sharedUnitTests();
}
