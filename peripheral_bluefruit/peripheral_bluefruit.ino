

#include <Arduino.h>
#include <SPI.h>

#include "Adafruit_BLE.h"
#include "Adafruit_BluefruitLE_SPI.h"
#include "Adafruit_BLEGatt.h"

#define BUFSIZE                        160   // Size of the read buffer for incoming data
#define VERBOSE_MODE                   false  // If set to 'true' enables debug output

#define BLUEFRUIT_SPI_CS               8
#define BLUEFRUIT_SPI_IRQ              7
#define BLUEFRUIT_SPI_RST              4    // Optional but recommended, set to -1 if unused

#define FACTORYRESET_ENABLE      1
#define CHANNEL_NUMBER 7

int8_t led = 13;

int32_t htsServiceId;
int32_t htsMeasureCharId;
uint16_t ppm[CHANNEL_NUMBER];
uint8_t *data;

Adafruit_BluefruitLE_SPI ble(BLUEFRUIT_SPI_CS, BLUEFRUIT_SPI_IRQ, BLUEFRUIT_SPI_RST);
Adafruit_BLEGatt gatt(ble);

void error(const __FlashStringHelper*err) {
	Serial.println(err);
	while (1);
}

void setup(void)
{
	Serial.begin(115200);

	Serial.print(F("Initialising the Bluefruit LE module: "));

	if ( !ble.begin(VERBOSE_MODE) )
		error(F("Couldn't find Bluefruit, make sure it's in CoMmanD mode & check wiring?"));

	Serial.println( F("OK!") );

	if ( FACTORYRESET_ENABLE )
		if ( ! ble.factoryReset() )
			error(F("Couldn't factory reset"));

	ble.echo(false);

	/* ------------ add service ---------------------- */

	htsServiceId = gatt.addService(0x4242);

	if (htsServiceId == 0)
		error(F("Could not add service"));

	/* ------------ add characteristic ---------------------- */

	htsMeasureCharId = gatt.addCharacteristic(0x4343, GATT_CHARS_PROPERTIES_WRITE_WO_RESP, 6, 6, BLE_DATATYPE_BYTEARRAY);

	if (htsMeasureCharId == 0)
		error(F("Could not add characteristic"));

	/* ------------------------------------------------------- */

	Serial.print(F("Performing a SW reset (service changes require a reset): "));
	ble.reset();
	ble.echo(false);

	data = (uint8_t*)gatt.buffer;
}

void loop(void)
{
	/* ------------ Read characteristic ---------------------- */

		gatt.getChar(1);

	/* ------------ Convert data[6] to ppm[7] ---------------- */

	ppm[0] = (data[0] << 2 | ((data[1] >> 6) & 0x03)) & 0x3ff;
	ppm[1] = (data[1] << 4 | ((data[2] >> 4) & 0x0f)) & 0x3ff;
	ppm[2] = (data[2] << 6 | ((data[3] >> 2) & 0x3f)) & 0x3ff;
	ppm[3] = (data[3] << 8 | ((data[4] >> 0) & 0xff)) & 0x3ff;

	ppm[4] = ((data[5] >> 4) & 0x3) * 341;
	ppm[5] = ((data[5] >> 2) & 0x3) * 341;
	ppm[6] = ((data[5] >> 0) & 0x3) * 341;

	/* ------------ Display info on Serial USB --------------- */

	for  (uint8_t i=0; i < 7; i++) {
		Serial.print(ppm[i], DEC);
		Serial.print(", ");
	}
	Serial.println((char*)data);

	/* ------------ Spektrum 1028 serial --------------- */

	Serial1.write(0x03);
	Serial1.write(0x01);
	uint16_t m = 0;
	for(uint8_t i=0; i < CHANNEL_NUMBER; i++)
	{
		ppm[i] &= 0x3ff;
		ppm[i] |= (m++ << 10);
		Serial1.write((ppm[i] >> 8) & 0xff);
		Serial1.write(ppm[i] & 0xff);
	}

	/* -------------------------------------------------- */


	delay(5);
}
