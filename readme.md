```md
# One-Off VPN on AWS

Launch a temporary self-hosted OpenVPN server on AWS with Terraform, use it for a few hours, and let it auto-terminate when finished.

This project is designed for simple, short-term VPN usage without committing to a monthly VPN subscription or maintaining a permanent server.

## Ideal for

- People who need a short-term, flexible VPN.
- People who want a self-hosted VPN instead of relying on a third-party VPN provider.
- People who already have AWS credits and want to use them.
- People who want a VPN server that can automatically terminate after a chosen number of hours.
- Travellers, testers, remote workers, and anyone who needs temporary IP relocation.

## Important note on privacy

This project gives you your **own** VPN server in your AWS account, which means you are not sending traffic through a commercial VPN provider.

However, this should not be described as a guaranteed “no log” solution. AWS account activity, billing records, and any logging you enable in your AWS environment may still exist. Use this as a short-lived self-hosted VPN, not as an anonymity tool.

## What this does

- Creates a temporary EC2 instance on AWS.
- Installs OpenVPN Access Server automatically.
- Generates a random VPN password.
- Outputs the server IP address.
- Lets you choose how many hours the server should stay alive.
- Terminates the instance automatically after the selected time.

## Prerequisites

You need the following before starting:

- An AWS account.
- AWS billing enabled, or AWS credits available.
- AWS credentials configured on your computer.
- Terraform installed on your computer.
- The OpenVPN Connect app installed on your phone or computer.
- Basic ability to run commands in Terminal, PowerShell, or Command Prompt.

## Files

Typical file used in this project:

- `main.tf` — the Terraform configuration.

## How to use

### Step 1: Put the Terraform file in a folder

Create a new folder and save the Terraform code as:

`main.tf`

### Step 2: Open Terminal

Open:

- Terminal on Mac
- Terminal on Linux
- PowerShell or Command Prompt on Windows

Then go into the folder where `main.tf` is saved.

Example:

```bash
cd path/to/your/vpn-folder
```

### Step 3: Initialize Terraform

Run:

```bash
terraform init
```

This downloads the required Terraform providers.

### Step 4: Launch the VPN

Run:

```bash
terraform apply --auto-approve -var="auto_shutdown_hours=72" -var="aws_region=us-east-1"
```

You can change:

- `auto_shutdown_hours=72` to any number of hours you want.
- `aws_region=us-east-1` to another AWS region if needed.

If you do not provide values, the default region is:

- `us-east-1`

### Step 5: Wait a few minutes

After Terraform finishes, wait around 3 minutes for OpenVPN to finish installing on the EC2 instance.

### Step 6: Get your VPN password

Run:

```bash
terraform output -raw vpn_password
```

Copy the password.

### Step 7: Connect in the OpenVPN app

Open the OpenVPN Connect app on your device.

Then:

1. Choose to add a new connection using URL or server address.
2. Enter the public IP shown by Terraform.
3. Username: `openvpn`
4. Password: paste the password from the previous step.
5. Accept the certificate warning if the app asks.

Once connected, your internet traffic will go through the AWS VPN server.

## Example

Example launch command:

```bash
terraform apply --auto-approve -var="auto_shutdown_hours=4" -var="aws_region=us-east-1"
```

Example login details after launch:

- Server/IP: the public IP shown in Terraform output
- Username: `openvpn`
- Password: from `terraform output -raw vpn_password`

## For non-technical users

This setup is easiest if someone technical launches it for you once and sends you:

- The server IP
- The username
- The password
- The number of hours before auto-termination

After that, your steps are simple:

1. Install OpenVPN Connect.
2. Open the app.
3. Add the server by IP.
4. Enter username `openvpn`.
5. Enter the password provided.
6. Connect.

That is all you need for normal use.

## How auto-termination works

The server is configured to shut itself down after the number of hours you choose.

Because the EC2 instance is set to terminate on instance-initiated shutdown, the server should delete itself instead of remaining stopped.

## How to terminate manually

If you want to stop using it immediately, terminate it from AWS or destroy it with Terraform.

### Option 1: Terraform destroy

Run this in the same folder:

```bash
terraform destroy --auto-approve -var="auto_shutdown_hours=72" -var="aws_region=us-east-1"
```

This is the best option because it removes the Terraform-managed resources cleanly.

### Option 2: Terminate from AWS Console

You can also:

1. Open the AWS Console.
2. Go to EC2.
3. Find the instance created by this project.
4. Terminate the instance.

Note: if you terminate only the EC2 instance manually, other Terraform-managed resources such as security groups or key-related resources may still remain until you run `terraform destroy`.

## Troubleshooting

### Terraform hangs or shows timeout on port 22

If SSH port 22 is closed, any SSH-based wait step will fail. Use the version of the Terraform code that does not rely on SSH checking.

### OpenVPN app cannot connect

Check:

- The instance is still running.
- Port 943 is open.
- Port 1194 UDP is open if your configuration uses it for VPN tunnel traffic.
- You waited long enough for OpenVPN to finish installing.
- You entered the correct username and password.

### Certificate warning appears

This is normal for a fresh self-hosted VPN unless you configure a trusted certificate. You can accept it in the app.

## Cost

This project creates AWS resources that may incur charges.

Costs depend on:

- EC2 instance type
- Region
- Data transfer usage
- How long the instance stays alive

If you have AWS credits, this can be a convenient way to use them for temporary VPN access.

## Safety notes

- Do not share your VPN password publicly.
- Do not leave the VPN running longer than needed.
- Destroy resources after use to avoid unnecessary charges.
- This project is for convenience and self-hosted access, not for high-anonymity use cases.

## Quick start

```bash
terraform init
terraform apply --auto-approve -var="auto_shutdown_hours=4" -var="aws_region=us-east-1"
terraform output -raw vpn_password
```

## Quick terminate

```bash
terraform destroy --auto-approve -var="auto_shutdown_hours=4" -var="aws_region=us-east-1"
```
```