const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

initializeApp();

exports.sendNewProductNotification = onDocumentCreated(
  "families/{familyId}/items/{itemId}",
  async (event) => {
    const newItem = event.data.data();
    const familyId = event.params.familyId;

    const itemName = newItem.name || "un producto";
    const addedBy = newItem.addedByName || "Alguien";

    const message = {
      notification: {
        title: "Nuevo producto añadido 🛒",
        body: `${addedBy} ha añadido '${itemName}' a la lista de la compra`,
      },
      topic: `family_${familyId}`,
    };

    try {
      await getMessaging().send(message);
      logger.info(`📩 Notificación enviada a topic family_${familyId}`, { itemName, addedBy });
    } catch (error) {
      logger.error("❌ Error al enviar notificación:", error);
    }
  }
);
