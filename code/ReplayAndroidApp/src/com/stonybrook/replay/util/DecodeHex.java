package com.stonybrook.replay.util;

public class DecodeHex {
	/*public static void main(String[] args) {
		String hexString = "474554202f6c65616e6261636b5f616a61783f616374696f6e5f656e7669726f6e6d656e743d3120485454502f312e310d0a486f73743a207777772e796f75747562652e636f6d0d0a436f6e6e656374696f6e3a204b6565702d416c6976650d0a557365722d4167656e743a20636f6d2e676f6f676c652e616e64726f69642e796f75747562652f352e322e3237284c696e75783b20553b20416e64726f696420342e322e323b20656e5f47423b2047542d4939333030204275696c642f4a445133392920677a69700d0a0d0a";    
		byte[] bytes;
		try {
			bytes = decodeHex(hexString .toCharArray());
			System.out.println(new String(bytes, "UTF8"));
		} catch (Exception e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}*/
	
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
