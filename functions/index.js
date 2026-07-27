const { onCall } = require("firebase-functions/v2/https");

exports.sayHello = onCall((request) => {
  return {
    message: "Hello from Firebase Functions!"
  };
});