# 🤖 Bot de WhatsApp para tu negocio (gratis y open source)

Bot hecho con **[BuilderBot](https://www.builderbot.app)** (open source) + **Gemini** (Google AI Studio, plan gratis).
Responde horarios, precios, dirección y preguntas frecuentes usando **solo** lo que escribas en `negocio.txt`.
Si no sabe algo, le dice al cliente que lo consultará y **te avisa por WhatsApp** y en el panel.

Incluye un **panel tipo WhatsApp Web** (http://localhost:3008) donde escaneas el QR, ves todas las conversaciones,
respondes tú y puedes **pausar el bot** en un chat para atenderlo personalmente.

## Paso a paso

1. **Instala Node.js** (versión LTS) desde https://nodejs.org → descarga, siguiente, siguiente, finalizar.
2. **Descarga este proyecto**: en GitHub, botón verde **Code → Download ZIP**, descomprímelo y entra a la carpeta `whatsapp-bot`.
3. **Crea tu clave gratis** en https://aistudio.google.com/apikey → *Create API key* → cópiala.
4. **Configura**: copia `.env.example` y renómbralo a `.env`. Ábrelo con el Bloc de notas y pega tu clave en `GEMINI_API_KEY=`.
   En `NUMERO_DUENO=` pon tu celular personal (ej. `56912345678`) para recibir los avisos.
5. **Escribe la info de tu negocio** en `negocio.txt` (horarios, precios, dirección, preguntas frecuentes).
6. **Inicia el bot**:
   - Windows: doble clic en `iniciar.bat`
   - Mac/Linux: abre una terminal en la carpeta y ejecuta `npm install` y luego `npm start`
7. **Escanea el QR**: abre http://localhost:3008 → en el celular: WhatsApp → *Dispositivos vinculados* → *Vincular un dispositivo*.
8. **Prueba**: desde otro celular escríbele al número del bot "¿A qué hora abren?".

El bot funciona mientras el computador esté encendido y la ventana abierta. La sesión queda guardada en `bot_sessions/`
(no tendrás que escanear de nuevo). Para desvincular, borra esa carpeta y cierra la sesión desde *Dispositivos vinculados*.

> ⚠️ BuilderBot+Baileys usa WhatsApp Web de forma no oficial. Úsalo con moderación (solo responder, no enviar spam masivo)
> para evitar bloqueos. Recomendado: usar un número de **WhatsApp Business**.
