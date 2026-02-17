import fs from "fs";
import toml from "@iarna/toml";
import nodemailer from "nodemailer";

const configPath = "./data/.zeroclaw/config.toml";

const configRaw = fs.readFileSync(configPath, "utf-8");
const config = toml.parse(configRaw);

const emailConfig = config.channels_config.email;

if (!emailConfig) {
  console.error("Email não configurado");
  process.exit(1);
}

// argumentos
const to = process.argv[2];
const subject = process.argv[3];
const text = process.argv[4];

if (!to || !subject || !text) {
  console.error("Uso: node send_email.js to subject text");
  process.exit(1);
}

const transporter = nodemailer.createTransport({
  host: emailConfig.smtp_host,
  port: emailConfig.smtp_port,
  secure: false,
  auth: {
    user: emailConfig.username,
    pass: emailConfig.password
  }
});

await transporter.sendMail({
  from: emailConfig.from_address,
  to,
  subject,
  text
});

console.log("Email enviado");
