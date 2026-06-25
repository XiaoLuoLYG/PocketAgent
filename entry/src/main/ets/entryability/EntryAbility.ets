import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import util from '@ohos.util';
import { AssetCredentialStore } from '../model/DynamicCredentialStore';
import { handleGmailOAuthRedirect } from '../model/GmailOAuthClient';
import { configureLocalProviderConfigFromRawJson, gmailOAuthConfigFromProvider, localProviderConfigDebugSummary } from '../model/ToolGatewayClient';
import { aiLogError, aiLogInfo } from '../model/AiphoneLogger';

const DOMAIN = 0x0000;
const LOCAL_PROVIDER_CONFIG_RAWFILE = 'aiphone_provider_config.json';
const GMAIL_REVERSED_CLIENT_SCHEME = 'com.googleusercontent.apps.358078200829-covuu6l8dgvs7kaejua7mrkke7e8833b:/oauth2redirect';
const GMAIL_OAUTH_URI_HINTS: string[] = [
  'com.example.aiphonedemo:/oauth/google',
  'com.example.aiphonedemo://oauth/google',
  'aiphone://oauth/google',
  GMAIL_REVERSED_CLIENT_SCHEME
];

function isGmailOAuthRedirectUri(uri: string): boolean {
  for (let index = 0; index < GMAIL_OAUTH_URI_HINTS.length; index++) {
    if (uri.indexOf(GMAIL_OAUTH_URI_HINTS[index]) === 0) {
      return true;
    }
  }
  return false;
}

function describeError(error: Error | Object | string | number | boolean | null | undefined): string {
  if (error === undefined || error === null) {
    return '';
  }
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string' || typeof error === 'number' || typeof error === 'boolean') {
    return error.toString();
  }
  return JSON.stringify(error);
}

function shouldInspectPotentialOAuthText(value: string): boolean {
  return value.indexOf('oauth') >= 0 ||
    value.indexOf('google') >= 0 ||
    value.indexOf('state=') >= 0 ||
    value.indexOf('code=') >= 0;
}

function decodeUriCandidate(value: string): string {
  try {
    return decodeURIComponent(value.replace(/\+/g, ' '));
  } catch (_err) {
    return value;
  }
}

function embeddedUriFromText(value: string): string {
  const decoded = decodeUriCandidate(value);
  const variants: string[] = value === decoded ? [value] : [value, decoded];
  for (let valueIndex = 0; valueIndex < variants.length; valueIndex++) {
    const candidateText = variants[valueIndex];
    for (let hintIndex = 0; hintIndex < GMAIL_OAUTH_URI_HINTS.length; hintIndex++) {
      const hint = GMAIL_OAUTH_URI_HINTS[hintIndex];
      const start = candidateText.indexOf(hint);
      if (start < 0) {
        continue;
      }
      let end = candidateText.length;
      const terminators: string[] = ['"', '\'', ' ', '\n', '\r', '\t', '<', '>', '}'];
      for (let termIndex = 0; termIndex < terminators.length; termIndex++) {
        const termAt = candidateText.indexOf(terminators[termIndex], start);
        if (termAt >= 0 && termAt < end) {
          end = termAt;
        }
      }
      return candidateText.substring(start, end);
    }
  }
  return '';
}

function appendGmailOAuthUriCandidates(candidates: string[], value: Object | string | number | boolean | null | undefined): void {
  if (value === undefined || value === null) {
    return;
  }
  if (typeof value === 'string') {
    if (!shouldInspectPotentialOAuthText(value)) {
      return;
    }
    candidates.push(value);
    const decoded = decodeUriCandidate(value);
    if (decoded !== value) {
      candidates.push(decoded);
    }
    const embedded = embeddedUriFromText(value);
    if (embedded.length > 0) {
      candidates.push(embedded);
    }
    return;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return;
  }
  try {
    appendGmailOAuthUriCandidates(candidates, JSON.stringify(value));
  } catch (_err) {
  }
}

function gmailOAuthWantParameterKeys(want: Want): string {
  const params = want.parameters;
  if (params === undefined || params === null) {
    return '';
  }
  const keys: string[] = [];
  Object.keys(params).forEach((key: string) => {
    keys.push(key);
  });
  return keys.join('|').substring(0, 240);
}

function gmailOAuthUriFromWant(want: Want): string {
  const candidates: string[] = [];
  appendGmailOAuthUriCandidates(candidates, want.uri);
  const params = want.parameters;
  if (params !== undefined && params !== null) {
    Object.keys(params).forEach((key: string) => {
      appendGmailOAuthUriCandidates(candidates, params[key]);
    });
  }
  for (let index = 0; index < candidates.length; index++) {
    const candidate = candidates[index];
    if (isGmailOAuthRedirectUri(candidate)) {
      return candidate;
    }
  }
  return '';
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    this.loadLocalProviderConfig();
    this.handleGmailOAuthWant(want);
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

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onNewWant');
    this.loadLocalProviderConfig();
    this.handleGmailOAuthWant(want);
  }

  private handleGmailOAuthWant(want: Want): void {
    const directUri = want.uri === undefined ? '' : want.uri;
    const uri = gmailOAuthUriFromWant(want);
    if (!isGmailOAuthRedirectUri(uri)) {
      const parameterKeys = gmailOAuthWantParameterKeys(want);
      if (directUri.indexOf('oauth') >= 0 || directUri.indexOf('google') >= 0 || parameterKeys.length > 0) {
        aiLogInfo('[AIPhone][GmailOAuthWantIgnored] directUriChars=' + directUri.length.toString() +
          ' directHasCode=' + (directUri.indexOf('code=') >= 0 ? 'true' : 'false') +
          ' directHasState=' + (directUri.indexOf('state=') >= 0 ? 'true' : 'false') +
          ' directHasError=' + (directUri.indexOf('error=') >= 0 ? 'true' : 'false') +
          ' parameterKeys=' + parameterKeys);
      }
      return;
    }
    const config = gmailOAuthConfigFromProvider();
    aiLogInfo('[AIPhone][GmailOAuthWantReceived] uriChars=' + uri.length.toString() +
      ' hasCode=' + (uri.indexOf('code=') >= 0 ? 'true' : 'false') +
      ' hasState=' + (uri.indexOf('state=') >= 0 ? 'true' : 'false') +
      ' hasError=' + (uri.indexOf('error=') >= 0 ? 'true' : 'false') +
      ' clientConfigured=' + (config.clientId.length > 0 ? 'true' : 'false') +
      ' secretConfigured=' + (config.clientSecret.length > 0 ? 'true' : 'false') +
      ' redirectChars=' + config.redirectUri.length.toString());
    handleGmailOAuthRedirect(new AssetCredentialStore(), gmailOAuthConfigFromProvider(), uri)
      .then(() => {
        aiLogInfo('[AIPhone][GmailOAuthWantSaved] ok=true');
        hilog.info(DOMAIN, 'testTag', '%{public}s', 'Gmail OAuth authorization saved.');
      })
      .catch((err: Error | Object | string | number | boolean | null | undefined) => {
        const message = describeError(err);
        aiLogError('[AIPhone][GmailOAuthWantFailed] ' + message);
        hilog.error(DOMAIN, 'testTag', 'Gmail OAuth callback failed. Cause: %{public}s', message);
      });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/A2uiHome/Index', (err) => {
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
