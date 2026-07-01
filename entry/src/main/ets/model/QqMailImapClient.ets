import socket from '@ohos.net.socket';
import util from '@ohos.util';
import { aiLogInfo } from './AiphoneLogger';
import { A2uiLabelValueData } from './A2uiTypes';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import { MailDraftArgs, MailSearchArgs, MailThreadResult } from './MailToolTypes';
import { utf8Bytes } from './Utf8Bytes';

export interface QqMailConfig {
  address: string;
  authCode: string;
  imapHost: string;
  imapPort: number;
  draftsMailbox: string;
}

export interface ImapTransport {
  connect(host: string, port: number): Promise<void>;
  send(line: string): Promise<void>;
  readUntil(tag: string): Promise<string[]>;
  close(): Promise<void>;
}

function bytesToBase64(bytes: Uint8Array): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let result = '';
  for (let index = 0; index < bytes.length; index += 3) {
    const first = bytes[index];
    const second = index + 1 < bytes.length ? bytes[index + 1] : 0;
    const third = index + 2 < bytes.length ? bytes[index + 2] : 0;
    const triple = (first << 16) | (second << 8) | third;
    result += alphabet.charAt((triple >> 18) & 0x3f);
    result += alphabet.charAt((triple >> 12) & 0x3f);
    result += index + 1 < bytes.length ? alphabet.charAt((triple >> 6) & 0x3f) : '=';
    result += index + 2 < bytes.length ? alphabet.charAt(triple & 0x3f) : '=';
  }
  return result;
}

function decodeBase64(value: string): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  const bytes = new Uint8Array(Math.ceil(value.length / 4) * 3);
  let byteIndex = 0;
  for (let index = 0; index < value.length; index += 4) {
    const a = alphabet.indexOf(value.charAt(index));
    const b = alphabet.indexOf(value.charAt(index + 1));
    const c = value.charAt(index + 2) === '=' ? -1 : alphabet.indexOf(value.charAt(index + 2));
    const d = value.charAt(index + 3) === '=' ? -1 : alphabet.indexOf(value.charAt(index + 3));
    if (a < 0 || b < 0) {
      continue;
    }
    const triple = (a << 18) | (b << 12) | ((c < 0 ? 0 : c) << 6) | (d < 0 ? 0 : d);
    bytes[byteIndex] = (triple >> 16) & 0xff;
    byteIndex++;
    if (c >= 0) {
      bytes[byteIndex] = (triple >> 8) & 0xff;
      byteIndex++;
    }
    if (d >= 0) {
      bytes[byteIndex] = triple & 0xff;
      byteIndex++;
    }
  }
  return decodeUtf8Bytes(bytes, byteIndex);
}

function decodeUtf8Bytes(bytes: Uint8Array, length: number): string {
  let result = '';
  let index = 0;
  while (index < length) {
    const first = bytes[index];
    if (first < 0x80) {
      result += String.fromCharCode(first);
      index++;
    } else if ((first & 0xe0) === 0xc0 && index + 1 < length) {
      const code = ((first & 0x1f) << 6) | (bytes[index + 1] & 0x3f);
      result += String.fromCharCode(code);
      index += 2;
    } else if ((first & 0xf0) === 0xe0 && index + 2 < length) {
      const code = ((first & 0x0f) << 12) | ((bytes[index + 1] & 0x3f) << 6) | (bytes[index + 2] & 0x3f);
      result += String.fromCharCode(code);
      index += 3;
    } else if ((first & 0xf8) === 0xf0 && index + 3 < length) {
      const code = ((first & 0x07) << 18) | ((bytes[index + 1] & 0x3f) << 12) | ((bytes[index + 2] & 0x3f) << 6) | (bytes[index + 3] & 0x3f);
      const normalized = code - 0x10000;
      result += String.fromCharCode(0xd800 + (normalized >> 10));
      result += String.fromCharCode(0xdc00 + (normalized & 0x3ff));
      index += 4;
    } else {
      index++;
    }
  }
  return result;
}

export function decodeMimeWords(value: string): string {
  const marker = '=?UTF-8?B?';
  let result = value;
  let start = result.toUpperCase().indexOf(marker);
  while (start >= 0) {
    const end = result.indexOf('?=', start + marker.length);
    if (end < 0) {
      return result;
    }
    const decoded = decodeBase64(result.substring(start + marker.length, end));
    result = result.substring(0, start) + decoded + result.substring(end + 2);
    start = result.toUpperCase().indexOf(marker, start + decoded.length);
  }
  return result;
}

function formatAddress(name: string, mailbox: string, host: string): string {
  const email = mailbox.length > 0 && host.length > 0 ? mailbox + '@' + host : mailbox;
  const display = decodeMimeWords(name).trim();
  if (email.length === 0) {
    return display;
  }
  return display.length > 0 ? display + ' <' + email + '>' : email;
}

function envelopeParts(line: string): string[] {
  const parts: string[] = [];
  let current = '';
  let quoted = false;
  let escaped = false;
  for (let index = 0; index < line.length; index++) {
    const char = line.charAt(index);
    if (escaped) {
      current += char;
      escaped = false;
      continue;
    }
    if (char === '\\' && quoted) {
      escaped = true;
      continue;
    }
    if (char === '"') {
      quoted = !quoted;
      continue;
    }
    if (!quoted && (char === '(' || char === ')' || char === ' ')) {
      if (current.length > 0) {
        parts.push(current);
        current = '';
      }
      continue;
    }
    current += char;
  }
  if (current.length > 0) {
    parts.push(current);
  }
  return parts;
}

function isoDate(value: string): string {
  const parts = value.split(' ');
  if (parts.length >= 6) {
    const day = parts[1].length === 1 ? '0' + parts[1] : parts[1];
    const month = monthNumber(parts[2]);
    const year = parts[3];
    const time = parts[4];
    const offset = parts[5];
    if (month.length > 0 && year.length === 4 && time.length >= 8 && offset.length === 5) {
      return year + '-' + month + '-' + day + 'T' + time + '.000' + offset.substring(0, 3) + ':' + offset.substring(3);
    }
  }
  const parsed = Date.parse(value);
  if (Number.isNaN(parsed)) {
    return '';
  }
  const text = new Date(parsed).toISOString();
  if (text.endsWith('Z')) {
    return text.substring(0, text.length - 1) + '+08:00';
  }
  return text;
}

function monthNumber(value: string): string {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  for (let index = 0; index < months.length; index++) {
    if (months[index] === value) {
      const number = index + 1;
      return number < 10 ? '0' + number.toString() : number.toString();
    }
  }
  return '';
}

function lastMessageId(parts: string[], fallback: string): string {
  for (let index = parts.length - 1; index >= 0; index--) {
    const value = parts[index];
    if (value.indexOf('@') >= 0 || value.indexOf('<') >= 0) {
      return value;
    }
  }
  return fallback;
}

export function parseImapEnvelopeList(lines: string[], accountLabel: string): MailThreadResult[] {
  const results: MailThreadResult[] = [];
  lines.forEach((line: string) => {
    const uidMatch = line.match(/UID ([0-9]+)/);
    if (uidMatch === null) {
      return;
    }
    const envelopeIndex = line.indexOf('ENVELOPE');
    if (envelopeIndex < 0) {
      return;
    }
    const parts = envelopeParts(line.substring(envelopeIndex));
    const date = parts.length > 1 ? parts[1] : '';
    const subject = parts.length > 2 ? decodeMimeWords(parts[2]) : '(no subject)';
    const fromName = parts.length > 3 && parts[3] !== 'NIL' ? parts[3] : '';
    const fromMailbox = parts.length > 5 && parts[5] !== 'NIL' ? parts[5] : '';
    const fromHost = parts.length > 6 && parts[6] !== 'NIL' ? parts[6] : '';
    const providerMessageId = lastMessageId(parts, uidMatch[1]);
    results.push({
      provider: 'qq',
      accountLabel: accountLabel,
      threadId: '',
      messageId: uidMatch[1],
      subject: subject,
      from: formatAddress(fromName, fromMailbox, fromHost),
      to: [],
      participants: [],
      snippet: subject,
      receivedAt: isoDate(date),
      unread: line.indexOf('\\\\Seen') < 0,
      important: line.indexOf('\\\\Flagged') >= 0,
      sourceUrl: '',
      rawProviderRef: providerMessageId
    });
  });
  return results;
}

export function pickDraftMailbox(mailboxes: string[], configured: string): string {
  if (configured.trim().length > 0) {
    return configured.trim();
  }
  const candidates = ['Drafts', '草稿箱', '&g0l6P3ux-'];
  for (let candidateIndex = 0; candidateIndex < candidates.length; candidateIndex++) {
    for (let index = 0; index < mailboxes.length; index++) {
      if (mailboxes[index] === candidates[candidateIndex]) {
        return mailboxes[index];
      }
    }
  }
  return 'Drafts';
}

function encodeHeader(value: string): string {
  let ascii = true;
  for (let index = 0; index < value.length; index++) {
    if (value.charCodeAt(index) > 127) {
      ascii = false;
      break;
    }
  }
  return ascii ? value : '=?UTF-8?B?' + bytesToBase64(utf8Bytes(value)) + '?=';
}

export function buildQqDraftMime(args: MailDraftArgs, fromAddress: string): string {
  const headers: string[] = [
    'From: ' + fromAddress,
    'To: ' + args.to.join(', '),
    'Subject: ' + encodeHeader(args.subject),
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8'
  ];
  if (args.messageId.trim().length > 0) {
    headers.push('In-Reply-To: ' + args.messageId.trim());
    headers.push('References: ' + args.messageId.trim());
  }
  return headers.join('\r\n') + '\r\n\r\n' + args.body + '\r\n';
}

function redactedAccountLabel(address: string): string {
  const at = address.indexOf('@');
  if (address.length === 0 || at <= 0) {
    return 'qq';
  }
  return address.substring(0, 1) + '***' + address.substring(at);
}

function selectedUidSet(lines: string[], pageSize: number): string {
  const ids: string[] = [];
  lines.forEach((line: string) => {
    if (line.indexOf('* SEARCH') < 0) {
      return;
    }
    const pieces = line.replace('* SEARCH', '').split(' ');
    pieces.forEach((piece: string) => {
      const value = piece.trim();
      if (/^[0-9]+$/.test(value)) {
        ids.push(value);
      }
    });
  });
  const size = Math.max(1, pageSize);
  return ids.slice(Math.max(0, ids.length - size)).join(',');
}

function imapQuoted(value: string): string {
  return '"' + value.replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
}

function imapKeywordTerms(query: string): string[] {
  const quoted: string[] = [];
  const quoteRegex = /"([^"]+)"/g;
  let match = quoteRegex.exec(query);
  while (match !== null) {
    if (match[1].trim().length > 0) {
      quoted.push(match[1].trim());
    }
    match = quoteRegex.exec(query);
  }
  const rawTerms = quoted.length > 0 ? quoted : query.split(/\s+/);
  const terms: string[] = [];
  rawTerms.forEach((term: string) => {
    const cleaned = term.replace(/[{}()]/g, '').trim();
    if (cleaned.length === 0 ||
      cleaned.indexOf(':') >= 0 ||
      cleaned.charAt(0) === '-' ||
      cleaned.toUpperCase() === 'OR') {
      return;
    }
    terms.push(cleaned);
  });
  return terms.slice(0, 3);
}

function imapSearchCriteria(query: string): string {
  const keys: string[] = [];
  const match = /newer_than:([0-9]+)d/i.exec(query);
  if (match !== null) {
    const days = Number.parseInt(match[1], 10);
    if (!Number.isNaN(days) && days > 0) {
      const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      keys.push('SINCE ' + since.getDate().toString() + '-' + months[since.getMonth()] + '-' + since.getFullYear().toString());
    }
  }
  imapKeywordTerms(query).forEach((term: string) => {
    keys.push('TEXT ' + imapQuoted(term));
  });
  return keys.length > 0 ? keys.join(' ') : 'ALL';
}

function visibleMatchesTerms(thread: MailThreadResult, terms: string[]): boolean {
  if (terms.length === 0) {
    return true;
  }
  const text = (thread.subject + ' ' + thread.snippet + ' ' + thread.from).toLowerCase();
  for (let index = 0; index < terms.length; index++) {
    if (text.indexOf(terms[index].toLowerCase()) >= 0) {
      return true;
    }
  }
  return false;
}

const DIGICERT_GLOBAL_ROOT_G2_CA = '-----BEGIN CERTIFICATE-----\n' +
  'MIIDjjCCAnagAwIBAgIQAzrx5qcRqaC7KGSxHQn65TANBgkqhkiG9w0BAQsFADBh\n' +
  'MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3\n' +
  'd3cuZGlnaWNlcnQuY29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBH\n' +
  'MjAeFw0xMzA4MDExMjAwMDBaFw0zODAxMTUxMjAwMDBaMGExCzAJBgNVBAYTAlVT\n' +
  'MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j\n' +
  'b20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IEcyMIIBIjANBgkqhkiG\n' +
  '9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuzfNNNx7a8myaJCtSnX/RrohCgiN9RlUyfuI\n' +
  '2/Ou8jqJkTx65qsGGmvPrC3oXgkkRLpimn7Wo6h+4FR1IAWsULecYxpsMNzaHxmx\n' +
  '1x7e/dfgy5SDN67sH0NO3Xss0r0upS/kqbitOtSZpLYl6ZtrAGCSYP9PIUkY92eQ\n' +
  'q2EGnI/yuum06ZIya7XzV+hdG82MHauVBJVJ8zUtluNJbd134/tJS7SsVQepj5Wz\n' +
  'tCO7TG1F8PapspUwtP1MVYwnSlcUfIKdzXOS0xZKBgyMUNGPHgm+F6HmIcr9g+UQ\n' +
  'vIOlCsRnKPZzFBQ9RnbDhxSJITRNrw9FDKZJobq7nMWxM4MphQIDAQABo0IwQDAP\n' +
  'BgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBhjAdBgNVHQ4EFgQUTiJUIBiV\n' +
  '5uNu5g/6+rkS7QYXjzkwDQYJKoZIhvcNAQELBQADggEBAGBnKJRvDkhj6zHd6mcY\n' +
  '1Yl9PMWLSn/pvtsrF9+wX3N3KjITOYFnQoQj8kVnNeyIv/iPsGEMNKSuIEyExtv4\n' +
  'NeF22d+mQrvHRAiGfzZ0JFrabA0UWTW98kndth/Jsw1HKj2ZL7tcu7XUIOGZX1NG\n' +
  'Fdtom/DzMNU+MeKNhJ7jitralj41E6Vf8PlwUHBHQRFXGU7Aj64GxJUTFy8bJZ91\n' +
  '8rGOmaFvE7FBcf6IKshPECBV1/MUReXgRPTqh5Uykw7+U0b6LJ3/iyK5S9kJRaTe\n' +
  'pLiaWN0bfVKfjllDiIGknibVb63dDcY3fe0Dkhvld1927jyNxF1WW6LZZm6zNTfl\n' +
  'MrY=\n' +
  '-----END CERTIFICATE-----';
const IMAP_READ_TIMEOUT_MS = 20000;

function imapCommandSummary(line: string): string {
  const parts = line.trim().split(' ');
  if (parts.length >= 2) {
    return parts[0] + ' ' + parts[1];
  }
  return parts.length === 1 ? parts[0] : 'unknown';
}

export class TlsImapTransport implements ImapTransport {
  private tcpSocket: socket.TCPSocket | null = null;
  private tlsSocket: socket.TLSSocket | null = null;
  private buffer: string = '';
  private decoder: util.TextDecoder = util.TextDecoder.create('utf-8');

  async connect(host: string, port: number): Promise<void> {
    aiLogInfo('[AIPhone][QqMailImapConnectStart] host=' + host + ' port=' + port.toString());
    this.tcpSocket = socket.constructTCPSocketInstance();
    await this.tcpSocket.bind({ address: '0.0.0.0', port: 0 });
    await this.tcpSocket.connect({
      address: { address: host, port: port },
      timeout: 15000
    });
    this.tlsSocket = socket.constructTLSSocketInstance(this.tcpSocket);
    this.tlsSocket.on('message', (value: socket.SocketMessageInfo) => {
      this.buffer += this.decoder.decodeToString(new Uint8Array(value.message), { stream: true });
    });
    await this.tlsSocket.connect({
      address: { address: host, port: port },
      secureOptions: { ca: [DIGICERT_GLOBAL_ROOT_G2_CA] },
      timeout: 15000
    });
    aiLogInfo('[AIPhone][QqMailImapConnectOk] host=' + host + ' port=' + port.toString());
  }

  async send(line: string): Promise<void> {
    if (this.tlsSocket === null) {
      throw new Error('IMAP socket is not connected.');
    }
    aiLogInfo('[AIPhone][QqMailImapSend] command=' + imapCommandSummary(line));
    const payload = utf8Bytes(line + '\r\n');
    await this.tlsSocket.send(payload.buffer.slice(payload.byteOffset, payload.byteOffset + payload.byteLength));
  }

  async readUntil(tag: string): Promise<string[]> {
    const started = Date.now();
    aiLogInfo('[AIPhone][QqMailImapReadStart] tag=' + tag);
    while (this.buffer.indexOf(tag + ' OK') < 0 && this.buffer.indexOf(tag + ' NO') < 0 && this.buffer.indexOf(tag + ' BAD') < 0) {
      if (Date.now() - started > IMAP_READ_TIMEOUT_MS) {
        aiLogInfo('[AIPhone][QqMailImapReadTimeout] tag=' + tag +
          ' bufferedChars=' + this.buffer.length.toString());
        throw new Error('QQ IMAP timeout waiting for ' + tag + ' buffered=' + this.buffer.substring(0, 120));
      }
      await new Promise<void>((resolve) => setTimeout(resolve, 50));
    }
    const text = this.buffer;
    this.buffer = '';
    const lines = text.split('\r\n').filter((line: string) => line.length > 0);
    aiLogInfo('[AIPhone][QqMailImapReadDone] tag=' + tag +
      ' lines=' + lines.length.toString() +
      ' chars=' + text.length.toString());
    return lines;
  }

  async close(): Promise<void> {
    if (this.tlsSocket !== null) {
      await this.tlsSocket.close();
      this.tlsSocket = null;
      this.tcpSocket = null;
    } else if (this.tcpSocket !== null) {
      await this.tcpSocket.close();
      this.tcpSocket = null;
    }
  }
}

export class QqMailImapClient {
  private config: QqMailConfig;
  private transportFactory: () => ImapTransport;

  constructor(config: QqMailConfig, transportFactory: (() => ImapTransport) | null = null) {
    this.config = config;
    this.transportFactory = transportFactory === null ? (() => new TlsImapTransport()) : transportFactory;
  }

  private async withTransport<T>(operation: (transport: ImapTransport) => Promise<T>): Promise<T> {
    const transport = this.transportFactory();
    try {
      await transport.connect(this.config.imapHost, this.config.imapPort);
      await transport.readUntil('*');
      return await operation(transport);
    } finally {
      await transport.close();
    }
  }

  async search(args: MailSearchArgs): Promise<MailThreadResult[]> {
    if (this.config.address.length === 0 || this.config.authCode.length === 0) {
      throw new Error('QQ Mail local config is missing QQ_MAIL_ADDRESS or QQ_MAIL_AUTH_CODE.');
    }
    return this.withTransport(async (transport: ImapTransport) => {
      await transport.send('a1 LOGIN "' + this.config.address + '" "' + this.config.authCode + '"');
      const login = await transport.readUntil('a1');
      if (login.join('\n').indexOf('a1 OK') < 0) {
        throw new Error('QQ IMAP login rejected.');
      }
      await transport.send('a2 SELECT INBOX');
      await transport.readUntil('a2');
      await transport.send('a3 UID SEARCH ' + imapSearchCriteria(args.query));
      const searchLines = await transport.readUntil('a3');
      const selected = selectedUidSet(searchLines, args.pageSize);
      if (selected.length === 0) {
        return [];
      }
      await transport.send('a4 UID FETCH ' + selected + ' (UID FLAGS ENVELOPE)');
      const fetchLines = await transport.readUntil('a4');
      const terms = imapKeywordTerms(args.query);
      return parseImapEnvelopeList(fetchLines, redactedAccountLabel(this.config.address))
        .filter((thread: MailThreadResult) => visibleMatchesTerms(thread, terms));
    });
  }

  async createDraft(args: MailDraftArgs): Promise<DynamicGenericToolResult> {
    if (this.config.address.length === 0 || this.config.authCode.length === 0) {
      throw new Error('QQ Mail local config is missing QQ_MAIL_ADDRESS or QQ_MAIL_AUTH_CODE.');
    }
    return this.withTransport(async (transport: ImapTransport) => {
      await transport.send('a1 LOGIN "' + this.config.address + '" "' + this.config.authCode + '"');
      const login = await transport.readUntil('a1');
      if (login.join('\n').indexOf('a1 OK') < 0) {
        throw new Error('QQ IMAP login rejected.');
      }
      await transport.send('a2 LIST "" "*"');
      const listLines = await transport.readUntil('a2');
      const mailboxes: string[] = [];
      listLines.forEach((line: string) => {
        const quote = line.lastIndexOf('"');
        const previous = line.lastIndexOf('"', quote - 1);
        if (previous >= 0 && quote > previous) {
          mailboxes.push(line.substring(previous + 1, quote));
        }
      });
      const mailbox = pickDraftMailbox(mailboxes, this.config.draftsMailbox);
      const mime = buildQqDraftMime(args, this.config.address);
      await transport.send('a3 APPEND "' + mailbox + '" (\\Draft) {' + utf8Bytes(mime).length.toString() + '}');
      await transport.send(mime);
      const append = await transport.readUntil('a3');
      if (append.join('\n').indexOf('a3 OK') < 0) {
        throw new Error('QQ IMAP draft append rejected.');
      }
      aiLogInfo('[AIPhone][QqMailDraftSaved] mailbox=' + mailbox + ' bodyChars=' + args.body.length.toString());
      const rows: A2uiLabelValueData[] = [
        { label: 'Source', value: 'QQ Mail' },
        { label: 'Mailbox', value: mailbox },
        { label: 'To', value: args.to.join(', ') },
        { label: 'Subject', value: args.subject },
        { label: 'Status', value: 'Saved draft, not sent' }
      ];
      const result: DynamicGenericToolResult = {
        sourceTag: 'QQ Mail',
        toolName: 'mail.draft.create',
        title: 'QQ 邮箱草稿已保存',
        status: 'success',
        summary: '已保存到真实 QQ 邮箱草稿箱；尚未发送。',
        rows: rows,
        rawPreview: 'qq draft saved mailbox=' + mailbox
      };
      return result;
    });
  }
}
