#  Automatically Assuming an AWS Role  

This step will configure your ** AWS credentials** automatically in the background **no manual input is required**.  

## What’s Happening in This Step?  

- We assume a pre-configured AWS IAM role.
- The system fetches temporary security credentials.
- These credentials are securely stored and applied.
- The process runs seamlessly in the background.

###  **Verifying Your AWS Identity**  

Once the background process completes, you can confirm your AWS identity by running:  


`aws sts get-caller-identity` {{exec}}

