// Confirmation and password reset emails, sent through Brevo SMTP with the HTML templates the Supabase project used
// (templates/*.html, copied from supabase/templates). Without SMTP settings the link is only logged, for local use.
import { readFileSync } from 'node:fs';
import nodemailer from 'nodemailer';
import type { Config } from '../config.ts';

export interface MailMessage { to: string; subject: string; text: string; html?: string }
export interface Mailer { send(message: MailMessage): Promise<void> }

const template = (name: string) => readFileSync(new URL(`../../templates/${name}`, import.meta.url), 'utf8');
const escapeHTML = (value: string) => value.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');

export type MailKind = 'confirmation' | 'recovery';

export function composeMail(kind: MailKind, to: string, link: string): MailMessage {
  const [file, subject, text] = kind === 'confirmation'
    ? ['confirm-signup.html', 'Xác nhận đăng ký Bé Khỏe', 'Mở liên kết để xác nhận email và bắt đầu dùng Bé Khỏe:']
    : ['reset-password.html', 'Đặt lại mật khẩu Bé Khỏe', 'Mở liên kết để đặt mật khẩu mới cho Bé Khỏe:'];
  return { to, subject, text: `${text}\n${link}`, html: template(file).replaceAll('{{ .ConfirmationURL }}', escapeHTML(link)).replaceAll('{{ .Email }}', escapeHTML(to)) };
}

export function smtpMailer(config: Config): Mailer {
  const smtp = config.smtp;
  if (!smtp || !smtp.user) {
    return { async send(message) { console.warn(`SMTP not configured; mail to ${message.to} not sent`); } };
  }
  const transport = nodemailer.createTransport({ host: smtp.host, port: smtp.port, secure: smtp.port === 465, auth: { user: smtp.user, pass: smtp.password } });
  return {
    async send(message) {
      await transport.sendMail({ from: { name: smtp.senderName, address: smtp.sender }, to: message.to, subject: message.subject, text: message.text, html: message.html });
    },
  };
}
