import { describe, it, expect } from '@ohos/hypium';

import { Logger, LogLevel } from '../../../main/ets/utils/Logger';

export default function loggerTest(): void {
  describe('Logger', () => {
    it('should merge repeated logs and output merged repeatCount', 0, () => {
      const logger = Logger.getInstance();
      logger.clearLogs();
      logger.setMinLevel(LogLevel.DEBUG);

      const originalInfo = console.info;
      let latestMessage = '';

      console.info = (message?: Object, ...args: Object[]): void => {
        const msgText = message === undefined ? '' : String(message);
        const suffix = args.length > 0 ? ` ${args.map((item: Object): string => String(item)).join(' ')}` : '';
        latestMessage = `${msgText}${suffix}`;
      };

      try {
        logger.info('LoggerTest', 'merge same log', 'same-data');
        logger.info('LoggerTest', 'merge same log', 'same-data');
      } finally {
        console.info = originalInfo;
      }

      const logs = logger.getLogs();
      expect(logs.length).assertEqual(1);
      expect(logs[0].repeatCount).assertEqual(2);
      expect(latestMessage.includes('(x2)')).assertTrue();

      logger.clearLogs();
    });
  });
}
