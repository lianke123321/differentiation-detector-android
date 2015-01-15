package com.stonybrook.replay.util;

public class DecodeHex {
	
	public static byte[] decodeHex(final char[] data) throws Exception {
		final int len = data.length;
		if ((len & 0x01) != 0) {
			throw new Exception("Odd number of characters.");
		}
		
		final byte[] out = new byte[len >> 1];
		
		// two characters form the hex value.
		for (int i = 0, j = 0; j < len; i++) {
			int f = toDigit(data[j], j) << 4;
			j++;
			f = f | toDigit(data[j], j);
			j++;
			out[i] = (byte) (f & 0xFF);
		}
		
		return out;
	}
	
	protected static int toDigit(final char ch, final int index) throws Exception {
		final int digit = Character.digit(ch, 16);
		if (digit == -1) {
			throw new Exception("Illegal hexadecimal character " + ch + " at index " + index);
		}
		return digit;
	}
}
