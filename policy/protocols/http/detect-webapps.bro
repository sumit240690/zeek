
@load http/utils

@load software
@load signatures

module HTTP;

redef signature_files += "http/detect-webapps.sig";
# Ignore the signatures used to match webapps
redef Signatures::ignored_ids += /^webapp-/;

export {
	redef enum Software::Type += {
		WEB_APPLICATION,
	};

	redef record Software::Info += {
		url:   string &optional &log;
	};
}

event signature_match(state: signature_state, msg: string, data: string) &priority=5
	{
	if ( /^webapp-/ !in state$sig_id ) return;
	
	local c = state$conn;
	local si = Software::parse(msg, c$id$resp_h, WEB_APPLICATION);
	si$url = build_url_http(c$http);
	if ( c$id$resp_h in Software::tracked &&
	     si$name in Software::tracked[c$id$resp_h] )
		{
		# If the new url is a substring of an existing, known url then let's
		# use that as the new url for the software.
		# PROBLEM: different version of the same software on the same server with a shared root path
		local is_substring = 0;
		if ( Software::tracked[c$id$resp_h][si$name]?$url )
			is_substring = strstr(Software::tracked[c$id$resp_h][si$name]$url, si$url);
		
		if ( is_substring == 1 )
			{
			Software::tracked[c$id$resp_h][si$name]$url = si$url;
			# Force the software to be logged because it indicates a URL
			# closer to the root of the site.
			si$force_log = T;
			}
		}
	
	Software::found(c$id, si);
	}
