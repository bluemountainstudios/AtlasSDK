# Atlas SDK

## Purpose
This project contains the Atlas Swift SDK (SPM package) used by iOS/macOS apps to:
- Configure API access
- Log in a user context
- Register devices for push notifications with the Atlas backend

## Change Workflow
After making any code changes, run the SDK build/tests before considering the work complete:

```bash
cd atlas-sdk
swift test
```
