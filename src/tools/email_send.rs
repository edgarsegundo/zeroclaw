use crate::tools::traits::{Tool, ToolResult};
use lettre::{Message, SmtpTransport, Transport};
use lettre::transport::smtp::authentication::Credentials;

pub struct EmailSendTool;

impl Tool for EmailSendTool {
    fn name(&self) -> &'static str {
        "email_send"
    }

    fn description(&self) -> &'static str {
        "Send an email via Gmail."
    }

    fn run(&self, params: &serde_json::Value) -> ToolResult {
        let to = params["to"].as_str().unwrap_or("");
        let subject = params["subject"].as_str().unwrap_or("No subject");
        let body = params["body"].as_str().unwrap_or("");
        let gmail_user = params["gmail_user"].as_str().unwrap_or("");
        let gmail_app_password = params["gmail_app_password"].as_str().unwrap_or("");

        let creds = Credentials::new(gmail_user.to_string(), gmail_app_password.to_string());

        let mailer = SmtpTransport::relay("smtp.gmail.com")
            .unwrap()
            .credentials(creds)
            .build();

        let email = Message::builder()
            .from(format!("ZeroClaw <{}>", gmail_user).parse().unwrap())
            .to(to.parse().unwrap())
            .subject(subject)
            .body(body.to_string())
            .unwrap();

        match mailer.send(&email) {
            Ok(_) => ToolResult::success("Email sent successfully."),
            Err(e) => ToolResult::error(format!("Failed to send email: {}", e)),
        }
    }
}
