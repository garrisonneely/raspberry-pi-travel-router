# Getting NordVPN Service Credentials

Your NordVPN service credentials are **different** from your regular NordVPN login credentials. These are specifically for OpenVPN manual configuration.

## Step-by-Step Instructions

### 1. Log into NordVPN Dashboard

1. Open your web browser
2. Go to: **https://my.nordaccount.com/**
3. Click the **"Log In"** button in the top right corner
4. Enter your NordVPN email and password
5. Complete any two-factor authentication if enabled

### 2. Navigate to Service Credentials

1. After logging in, you'll be on your account dashboard
2. Look for the left sidebar menu
3. Click on **"Services"**
4. Under the Services section, click on **"NordVPN"**

### 3. Access Manual Setup Credentials

1. Scroll down to find the **"Manual Setup"** section
2. You may see a tab or section labeled **"Set up NordVPN manually"** or **"Manual configuration"**
3. Click on this section to expand it

### 4. Generate or View Credentials

You'll see two options:

#### Option A: Service Credentials Already Exist
- You'll see:
  - **Service username**: A long string (e.g., `aBcDeFgHiJkLmNoPqRsTu`)
  - **Service password**: Another string (click "Show" or the eye icon to reveal)

#### Option B: Need to Generate Credentials
- If you see **"Generate new credentials"** or **"Create service credentials"**:
  1. Click the **"Generate new credentials"** button
  2. Wait a few seconds
  3. Your new service credentials will appear
  4. **Service username** and **Service password** will be displayed

### 5. Copy Your Credentials

⚠️ **Important**: These are NOT your regular NordVPN login credentials!

1. Click the **copy icon** next to the username (or manually select and copy)
2. Save it temporarily in a text file on your computer
3. Click **"Show"** or the eye icon next to the password
4. Click the **copy icon** or manually copy the password
5. Add it to your temporary text file

### 6. Keep Credentials Secure

- These credentials allow OpenVPN access to your NordVPN account
- Do not share them publicly
- You can regenerate them at any time if compromised
- The old credentials will stop working if you regenerate new ones

## Troubleshooting

### Can't Find "Manual Setup" Section

1. Make sure you're logged into **my.nordaccount.com** (not the main nordvpn.com site)
2. Try these direct links:
   - Dashboard: https://my.nordaccount.com/dashboard/
   - Services: https://my.nordaccount.com/dashboard/services/
3. Look for "Manual Setup", "OpenVPN", or "Advanced Configuration"

### Account Shows No Active Subscription

- Verify your NordVPN subscription is active
- Check billing status in account settings
- Contact NordVPN support if subscription issues exist

### Generated Credentials Don't Work

1. Try regenerating new credentials (old ones will be invalidated)
2. Ensure you're copying the entire string (no extra spaces)
3. Wait 5-10 minutes after generation before using
4. Verify your account is in good standing

## Visual Guide Reference

The layout should look similar to this:

```
┌─────────────────────────────────────────┐
│ Manual Setup                            │
├─────────────────────────────────────────┤
│ Set up NordVPN manually                 │
│                                         │
│ Service credentials                     │
│ Username: aBcDeFgHiJkLmNoPqRsTu  [Copy] │
│ Password: ********************* [Show]  │
│                                         │
│ [Generate new credentials]              │
└─────────────────────────────────────────┘
```

## Quick Reference

- **Website**: https://my.nordaccount.com/
- **Section**: Services → NordVPN → Manual Setup
- **What you need**: Service Username + Service Password
- **Format**: Both are long alphanumeric strings
- **Not**: Your email/regular password

## During Installation

When the installation script asks for credentials:

```
NordVPN service username: [paste your service username here]
NordVPN service password: [paste your service password here]
```

The credentials will be stored securely in `/etc/openvpn/nordvpn-credentials` with 600 permissions (readable only by root).
