package com.stonybrook.replay.exception_handler;

public class IpFlippingException extends Exception {

	/**
     * Using this custom exception when replay is aborted 
     * due to traffic modification.
     * 
     * @author Adrian
     */
	private static final long serialVersionUID = -5723566360289896036L;

	public IpFlippingException(){
        super();
    }

    public IpFlippingException(String message){
        super(message);
    }
}