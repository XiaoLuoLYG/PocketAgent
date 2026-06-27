import { A2uiAction } from '../../../model/A2uiTypes';
import { HtmlHomeAction, HtmlHomeBlock, HtmlHomeDocument } from './HtmlHomeTypes';

type HtmlHomePolicyValue = Object | string | number | boolean | null | undefined;

interface HtmlDynamicCredentialPayload {
  credentialRef?: string;
  credentialValue?: string;
  toolId?: string;
  prompt?: string;
}

export function isHtmlHomeActionAllowed(document: HtmlHomeDocument, action: A2uiAction): boolean {
  if (action.id.length === 0) {
    return false;
  }
  if (action.id === 'flight_retry_date') {
    return hasBlockKind(document, 'flight-option');
  }
  for (let index = 0; index < document.actions.length; index++) {
    if (sameAction(document.actions[index], action)) {
      return true;
    }
  }
  for (let blockIndex = 0; blockIndex < document.blocks.length; blockIndex++) {
    const block = document.blocks[blockIndex];
    if (action.id === 'html_dynamic_save_and_test' && dynamicCredentialAllowed(block, action)) {
      return true;
    }
    for (let actionIndex = 0; actionIndex < block.actions.length; actionIndex++) {
      if (sameAction(block.actions[actionIndex], action)) {
        return true;
      }
    }
  }
  return false;
}

function sameAction(expected: HtmlHomeAction, actual: A2uiAction): boolean {
  return expected.id === actual.id &&
    expected.kind === actual.kind &&
    expected.prompt === actual.prompt &&
    actionArgsJson(expected.args) === actionArgsJson(actual.args);
}

function actionArgsJson(args: Object | undefined): string {
  if (args === undefined || args === null) {
    return '';
  }
  return JSON.stringify(args);
}

function hasBlockKind(document: HtmlHomeDocument, kind: string): boolean {
  for (let index = 0; index < document.blocks.length; index++) {
    if (document.blocks[index].kind === kind) {
      return true;
    }
  }
  return false;
}

function dynamicCredentialAllowed(block: HtmlHomeBlock, action: A2uiAction): boolean {
  if (block.kind !== 'dynamic-tool-connect') {
    return false;
  }
  let payload: HtmlDynamicCredentialPayload;
  try {
    payload = JSON.parse(action.prompt) as HtmlDynamicCredentialPayload;
  } catch (_error) {
    return false;
  }
  const credentialValue = policyText(payload.credentialValue).trim();
  return credentialValue.length > 0 &&
    policyText(payload.credentialRef) === policyText(block.credentialRef) &&
    policyText(payload.toolId) === policyText(block.toolId) &&
    policyText(payload.prompt) === policyText(block.prompt);
}

function policyText(value: HtmlHomePolicyValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}
