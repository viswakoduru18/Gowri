import { SignJWT, jwtVerify } from 'jose';
import type { NextFunction, Request, Response } from 'express';

export interface SessionClaims {
  customerId: string;
  contactId: string;
  phone: string;
}

export class Sessions {
  private readonly key: Uint8Array;

  constructor(secret: string) {
    this.key = new TextEncoder().encode(secret);
  }

  issue(c: SessionClaims): Promise<string> {
    return new SignJWT({ ...c }).setProtectedHeader({ alg: 'HS256' }).setIssuedAt().setExpirationTime('90d').sign(this.key);
  }

  async verify(token: string): Promise<SessionClaims> {
    const { payload } = await jwtVerify(token, this.key);
    if (payload.kind) throw new Error('not a session token');
    return { customerId: String(payload.customerId), contactId: String(payload.contactId), phone: String(payload.phone) };
  }

  signLink(l: { contactId: string; salesOrderId: string }): Promise<string> {
    return new SignJWT({ ...l, kind: 'invoice' }).setProtectedHeader({ alg: 'HS256' }).setIssuedAt().setExpirationTime('5m').sign(this.key);
  }

  async verifyLink(token: string): Promise<{ contactId: string; salesOrderId: string }> {
    const { payload } = await jwtVerify(token, this.key);
    if (payload.kind !== 'invoice') throw new Error('wrong token kind');
    return { contactId: String(payload.contactId), salesOrderId: String(payload.salesOrderId) };
  }

  middleware() {
    return async (req: Request, res: Response, next: NextFunction) => {
      const token = req.header('authorization')?.replace(/^Bearer\s+/i, '');
      if (!token) return res.status(401).json({ error: 'Sign in to continue.' });
      try {
        res.locals.session = await this.verify(token);
        next();
      } catch {
        res.status(401).json({ error: 'Your session expired. Sign in again.' });
      }
    };
  }
}
