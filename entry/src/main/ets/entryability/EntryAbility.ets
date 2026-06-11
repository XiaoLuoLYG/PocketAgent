import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import util from '@ohos.util';
import { configureLocalProviderConfigFromRawJson, localProviderConfigDebugSummary } from '../model/ToolGatewayClient';

const DOMAIN = 0x0000;
const LOCAL_PROVIDER_CONFIG_RAWFILE = 'aiphone_provider_config.json';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    this.loadLocalProviderConfig();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  private loadLocalProviderConfig(): void {
    try {
      const bytes = this.context.resourceManager.getRawFileContentSync(LOCAL_PROVIDER_CONFIG_RAWFILE);
      const decoder = util.TextDecoder.create('utf-8');
      configureLocalProviderConfigFromRawJson(decoder.decodeToString(bytes));
      hilog.info(DOMAIN, 'testTag', 'Loaded local provider config. %{public}s', localProviderConfigDebugSummary());
    } catch (err) {
      hilog.info(DOMAIN, 'testTag', 'Local provider config not loaded from %{public}s. Cause: %{public}s', LOCAL_PROVIDER_CONFIG_RAWFILE, JSON.stringify(err));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
