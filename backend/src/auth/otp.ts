import { randomInt } from 'node:crypto';
import type { Config } from '../config.js';
import type { Store } from '../store.js';

export interface SmsSender {
  send(phone: string, code: string): Promise<void>;
}

export class ConsoleSms implements SmsSender {
  async send(phone: string, code: string) {
    console.log(`[otp] +91 ${phone}: ${code}`);
  }
}

/** MSG91 OTP API (DLT-registered template required in India). */
export class Msg91Sms implements SmsSender {
  constructor(
    private readonly authKey: string,
    private readonly templateId: string,
  ) {}

  async send(phone: string, code: string) {
    const res = await fetch('https://control.msg91.com/api/v5/otp?' + new URLSearchParams({ template_id: this.templateId, mobile: `91${phone}`, otp: code }), {
      method: 'POST',
      headers: { authkey: this.authKey },
    });
    if (!res.ok) throw new Error(`MSG91 send failed: ${res.status}`);
  }
}

export function smsSender(cfg: Config['otp']): SmsSender {
  return cfg.provider === 'msg91' ? new Msg91Sms(cfg.msg91AuthKey, cfg.msg91TemplateId) : new ConsoleSms();
}

const TTL_MS = 5 * 60_000;
const MAX_ATTEMPTS = 5;

export class OtpService {
  constructor(
    private readonly store: Store,
    private readonly sms: SmsSender,
  ) {}

  async send(phone: string): Promise<void> {
    const existing = this.store.otps.get(phone);
    if (existing && existing.expiresAt - TTL_MS + 30_000 > Date.now()) {
      throw new OtpError('Please wait 30 seconds before asking for a new code.');
    }
    const code = String(randomInt(0, 10_000)).padStart(4, '0');
    this.store.otps.set(phone, { code, expiresAt: Date.now() + TTL_MS, attempts: 0 });
    await this.sms.send(phone, code);
  }

  verify(phone: string, code: string): boolean {
    const e = this.store.otps.get(phone);
    if (!e || e.expiresAt < Date.now()) throw new OtpError('That code has expired. Request a new one.');
    if (++e.attempts > MAX_ATTEMPTS) {
      this.store.otps.delete(phone);
      throw new OtpError('Too many attempts. Request a new code.');
    }
    if (e.code !== code) return false;
    this.store.otps.delete(phone);
    return true;
  }
}

export class OtpError extends Error {}
