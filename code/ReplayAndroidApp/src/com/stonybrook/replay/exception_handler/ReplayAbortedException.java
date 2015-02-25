package com.stonybrook.replay.exception_handler;

public class ReplayAbortedException extends Exception {

    /**
     * Using this custom exception when replay is aborted 
     * due to traffic modification.
     * 
     * @author Adrian
     */
	private static final long serialVersionUID = -6138402809087412455L;

	public ReplayAbortedException(){
        super();
    }

    public ReplayAbortedException(String message){
        super(message);
    }
}