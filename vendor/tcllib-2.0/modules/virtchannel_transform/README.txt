base64, hex

	Base64 and hex de- and encoding of data flowing
	through a channel.

	Encodes on write, decodes on read.

identity

	No transformation

counter

	Identity, counting bytes.

adler32, adler32pure, crc32

	Compute checksums and write to external variables.

observe

	Divert copy of the data to additional channels.

limitsize

	Force EOF after reading N bytes, N configurable.

spacer

	Inserts separator string every n bytes.

otp

	One-Time-Pad encryption.

zlib

	zlib (de)compression (deflate, inflate).
