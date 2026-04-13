package main

import qrcode "github.com/skip2/go-qrcode"

func generateQRPNG(data string, size int) ([]byte, error) {
	return qrcode.Encode(data, qrcode.Medium, size)
}
