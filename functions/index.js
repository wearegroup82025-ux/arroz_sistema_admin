const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.paymongoWebhook = functions.https.onRequest(async (req, res) => {
    try {
        // Kinukuha ang event object mula sa katawan ng request ng PayMongo
        const event = req.body.data.attributes;
        const eventType = event.type; // Halimbawa: "checkout_session.payment.paid"

        if (eventType === 'checkout_session.payment.paid') {
            // Dito kinukuha ang details ng checkout session resource
            const sessionData = event.data.attributes;
            
            // Kunin ang orderId na ipinasa natin bilang metadata sa Checkout Session API
            const orderId = sessionData.metadata ? sessionData.metadata.orderId : null;

            if (orderId) {
                // Pag nahanap ang orderId, i-update ang status sa Firestore patungong "To Ship"
                await admin.firestore().collection('orders').doc(orderId).update({
                    status: 'To Ship',
                    isPaid: true,
                    paymentStatus: 'Paid via PayMongo'
                });
                console.log(`Order ${orderId} successfully updated to 'To Ship'.`);
            } else {
                console.error("No orderId found in transaction metadata.");
            }
        }
        
        // Palaging magbalik ng HTTP 200 OK sa PayMongo para hindi sila mag-retry nang mag-retry
        res.status(200).send('Webhook Received Successfully');
    } catch (error) {
        console.error("Webhook Error:", error);
        res.status(500).send("Internal Server Error");
    }
});