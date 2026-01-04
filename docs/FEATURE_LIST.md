# Silver Project

**A professional, self-hosted email solution that puts you in complete control.**

---

## Features Overview

| Feature | Description | Status |
|---------|-------------|--------|
| **Unmatched Cost Efficiency – Free!** | Imagine your organization has 1,000 employees. How much are you spending on email services? With popular providers like Google Workspace ($6-7/user/month) or Microsoft 365 ($12.50/user/month), you're spending $72,000-150,000 per year.<sup>[1](#ref1),[2](#ref2)</sup> Now imagine cutting that cost to minimal infrastructure expenses—while still providing a professional, secure, role-based email system. With Silver Project, that's reality. Affordable, powerful, and fully under your control. | Completed |
| **Lightweight Infrastructure Requirements** | Do you need powerful CPUs or huge amounts of memory? No. Silver Project is extremely lightweight and optimized to run on minimal infrastructure without compromising performance or reliability. Lower costs, easier deployment, less maintenance—while delivering a full-featured, professional email experience. | Approved |
| **Professional Role-Based Email Identity** | When you receive an email from `anura@gmail.com`, do you really remember who sent it? Personal emails lack organizational authority. Now imagine using role-based addresses like `ceo@yourcompany.com`, `support@yourcompany.com`, or `sales@yourcompany.com`. Recipients immediately see the credibility and authority behind the message. It's not just an email—it's a representation of your organization. | In Progress |
| **Complete Data Ownership & Security** | When you send sensitive information via Gmail or other public providers, do you know where that data goes? Can you control who accesses it? With Silver Project, you can. Your data stays exactly where you decide. You control the storage, access, infrastructure, and entire security lifecycle. Full transparency, full ownership, full peace of mind. | Completed |
| **Reliable & Disaster-Proof Backups** | What happens if your server crashes, burns, or gets stolen? With Silver Project's reliable backup strategy, your data remains safe and protected. Configure backups according to your needs—your information stays intact even in worst-case scenarios. | Not Started |
| **Built-In Spam & Virus Protection** | Do you need special firewalls or external tools? No. Silver Project includes enterprise-grade protection: advanced spam filtering, malware scanning, and security controls—all built in. No extra firewalls, no additional appliances, no hidden costs. Complete, integrated protection from day one. | Completed |
| **Effortless Group Emailing** | Tired of typing long CC lists? Organize people into groups and send emails to a single group address—everyone receives it instantly. Simple, efficient, and eliminates the hassle of manually adding multiple recipients every time. | Not Started |
| **Identity Provider (IdP) Separation** | Already using an Identity Provider such as Thunder, Keycloak, Azure AD, or Okta? Our email system integrates seamlessly with your existing IdP, allowing you to manage email accounts using the same identities, roles, and access policies—eliminating duplication and simplifying user management. | Not Started |
| **Email Workflow Automation** | Emails sent to organizational addresses can follow predefined workflows, where authorized users take actions, apply labels, and move the email through different stages. Senders can track the status of their requests, bringing transparency and structure to email-based processes. | Not Started |
| **Native High-Performance Email Client** | Our native email client supports both IMAP and JMAP, a modern protocol designed for faster synchronization and efficient email processing. JMAP uses JSON and HTTP to enable batch requests, reducing network roundtrips and improving sync speed—especially on mobile networks and limited bandwidth connections.<sup>[3](#ref3),[4](#ref4),[5](#ref5)</sup> This ensures a responsive, future-ready email experience across devices and networks. | Not Started |
| **Email Expiration & Lifecycle Control** | Senders can define expiration dates for emails, after which messages are automatically marked as expired and governed by retention policies. This helps manage sensitive or time-bound communications more securely. | Not Started |
| **Attachment Storage in Object Storage** | Attachments are stored separately in object storage while emails retain only references, significantly reducing mailbox size and storage costs. Object storage excels at handling large volumes of unstructured data like email attachments, offering unlimited scalability and lower costs compared to traditional file storage.<sup>[6](#ref6),[7](#ref7)</sup> This approach improves performance, scalability, and backup efficiency. | Not Started |

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| Completed | Feature is fully implemented |
| Approved | Feature is approved and ready |
| In Progress | Currently under development |
| Not Started | Planned for future implementation |

---

## References

| # | Source | Link |
|---|--------|------|
| <a name="ref1">1</a> | Google Workspace Pricing - Business Starter: $6/user/month (annual) | https://workspace.google.com/pricing |
| <a name="ref2">2</a> | Microsoft 365 Business Standard: $12.50/user/month (annual) | https://learn.microsoft.com/en-us/answers/questions/5277363/ |
| <a name="ref3">3</a> | JMAP Protocol Performance: Batch requests reduce network calls significantly | https://mailtemi.com/blog/why-jmap-is-faster/ |
| <a name="ref4">4</a> | IETF JMAP Specification: Modern protocol using JSON over HTTP | https://www.ietf.org/blog/jmap/ |
| <a name="ref5">5</a> | JMAP vs IMAP Comparison: Faster sync and better mobile performance | https://linagora.com/en/topics/what-are-differences-between-imap-and-jmap |
| <a name="ref6">6</a> | Object Storage for Email: Ideal for long-term retention and compliance archiving | https://www.ibm.com/think/topics/object-vs-file-vs-block-storage |
| <a name="ref7">7</a> | Object Storage Scalability: Unlimited storage capacity with lower costs | https://cloudian.com/guides/object-storage/object-storage-vs-file-storage/ |
