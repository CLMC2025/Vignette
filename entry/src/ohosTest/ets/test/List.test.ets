import abilityTest from './Ability.test';
import loggerTest from './Logger.test';
import webDavSyncManagerIncrementalTest from './WebDavSyncManagerIncremental.test';
import dataSyncManagerUserBookImportBenchmarkTest from './DataSyncManagerUserBookImportBenchmark.test';

export default function testsuite() {
  abilityTest();
  loggerTest();
  webDavSyncManagerIncrementalTest();
  dataSyncManagerUserBookImportBenchmarkTest();
}
