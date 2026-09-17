🎯 **What:** The testing gap addressed
The `analyze_audio` endpoint lacked tests for handling general exceptions that may occur during the internal `analyze_tone` process. This PR addresses that gap by mocking the audio analyzer to raise a generic exception and verifying that the endpoint successfully catches it, logs the error, and raises a 500 `HTTPException` with the relevant details.

📊 **Coverage:** What scenarios are now tested
- Uploading audio files that result in internal analyzer exceptions.
- Verifying that generic runtime exceptions fallback to a standard `500 Internal Server Error` response.

✨ **Result:** The improvement in test coverage
Increased reliability for the `/api/v1/audio/analyze-audio` endpoint. Prevents regressions in exception handling and correctly bubbles up server errors securely.
