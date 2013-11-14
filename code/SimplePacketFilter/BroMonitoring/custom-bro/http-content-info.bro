module HTTP;

export {
	## The number of bytes that will be included in the http
	## log from the client body.
	const post_body_limit = 8192;
	
	redef record Info += {
		content_length:	string	&log	&optional;
		content_encoding:	string	&log	&optional;
		content_type:	string	&log	&optional;
		transfer_encoding:	string	&log	&optional;
		post_body: string &log &optional;
	};
	
}

event http_entity_data(c: connection, is_orig: bool, length: count, data: string)
	{
	if ( is_orig )
		{
		if ( ! c$http?$post_body )
			c$http$post_body = sub_bytes(data, 0, post_body_limit);
		else if ( |c$http$post_body| < post_body_limit )
			c$http$post_body = string_cat(c$http$post_body, sub_bytes(data, 0, post_body_limit-|c$http$post_body|));
		}	
	}

event http_header(c: connection, is_orig: bool, name: string, value: string)
	{
	if ( ! is_orig ) 
		{
		if ( name == "CONTENT-LENGTH" )
			{
				c$http$content_length = value;
			}
		else if ( name == "CONTENT-TYPE" ) 
			{
				c$http$content_type = value;
			}
		else if ( name == "CONTENT-ENCODING" ) 
			{
				c$http$content_encoding = value;
			}
		else if ( name == "TRANSFER-ENCODING" )
			{
				c$http$transfer_encoding = value;
			}
		}
	}
