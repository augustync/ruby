#!/usr/local/opt/ruby/bin/ruby
# -*- coding: UTF-8 -*-
require 'httparty' ;
require 'json'
require 'optparse'
require 'ostruct'

dir=Dir.pwd.split('/')
pod_dir=dir[dir.length - 1]

def got_success?(success)

        unless success.success?
                puts "Sous Chef instance returned #{success.code}"
                exit
        end
end

def get_sensu_server(server_name)
        sensu_list = Hash.new ;
        get_sensu=HTTParty.get("http://souschef.atlis1/sc/d/prod?iter&sort")

        got_success?(get_sensu)

        #servers_prod=get_sensu.body.split("\n")
        servers_prod = JSON.load(get_sensu.body)
        servers_prod.each do |x|
                if x.include?('sensu')
                        sensu_list[x.split('.')[1]]=x
                end
        end

        if server_name.include?("che01is")
                sensu=sensu_list[server_name.split('-')[0]]
                if sensu.nil?
                    sensu='che01is-prod-sensu01.adm01.com'
                end
                puts sensu
                return sensu
        elsif server_name.include?("adm01.com")
                sensu=sensu_list[server_name.split('-')[0]]
                if sensu.nil?
                    sensu='vsensu02.atlis1'
                end
                puts sensu
                return sensu
        elsif server_name.include?("prod.awspr")
                sensu=nil
                if server_name.include?("ca-as1")
                    sensu='mon1-ca-poda-sprod-as1.prod.awspr'
                elsif server_name.include?("ca-ase1")
                    sensu='mon1-ca-pod7-sprod-ase1.prod.awspr'
                elsif server_name.include?("ca-ec1")
                    sensu='mon1-ca-pod6-sprod-ec1.prod.awspr'
                elsif server_name.include?("ca-cc1")
                    sensu='mon1-ca-pod8-sprod-cc1.prod.awspr'
                elsif server_name.include?("ca-ase2")
                    sensu='mon1-ca-pod7-sprod-ase1.prod.awspr'
                else
                    sensu='vsensu02.atlis1'
                end
                puts sensu
                return sensu
        else
                sensu=sensu_list[server_name.split('.')[1]]
                if sensu.nil?
                    sensu='vsensu02.atlis1'
                end
                puts sensu
                return sensu
        end
        puts sensu
end


def mypod_servers(_pod)
        get_apps=HTTParty.get("http://souschef.atlis1/sc/d/pod2appservers/#{_pod}?iter&sort=desc")
        get_bgs=HTTParty.get("http://souschef.atlis1/sc/d/pod2bgservers/#{_pod}?iter&sort=desc")

        got_success?(get_apps)
        got_success?(get_bgs)

        apps = JSON.load(get_apps.body)
        bgs = JSON.load(get_bgs.body)
        apps.concat(bgs)
        return apps
end


def verify_pod(_pod)
	v=HTTParty.get("http://souschef.atlis1/sc/d/pod2bgservers?iter&sort")
	got_success?(v)

        pods = JSON.load(v.body)

	pods.each do |pod|
		if pod.downcase.eql?(_pod.downcase)
			return pod
		end
	end
	return nil
end


options = OpenStruct.new
OptionParser.new do |opt|
  opt.banner = "Usage: \n\tsensu_silence.rb [options] [flag]\nExample: \n\tsensu_silence.rb -p stage1 -s"
  opt.separator ""
  opt.separator "Specific options:"

  opt.on('-p pod', '--pod pod', '[OPTION] Where --pod podX or --pod stageX or --pod <1|2|..|n>  or --pod <s1|s2|...|sn>') do |pod|
	  options.pod = verify_pod(pod)
  end

  opt.on('-h host', '--server host', '[OPTION] Act on a single server. Cannot be used with --pod option.') do |host|
	  options.server = host
  end

  opt.separator ""
  opt.separator "Specific flags:"

  opt.on('-s', '--status', '[FLAG] Status pod/server sensu state') do |s|
	  options.status = true
  end

  opt.on('-r', '--prod', '[FLAG] Send pod/server to production mode in sensu') do |r|
          options.prod = true
  end

  opt.on('-m', '--mtc', '[FLAG] Send pod/server to maintenance mode in sensu') do |m|
	  options.mtc = true
  end

  opt.on('-a', '--alerts', '[FLAG] List current alerts for pod/device. Only alerts at CRITICAL level - Oracle hosts NOT included') do |a|
	  options.alerts = true
  end

  opt.on('-v','--version', 'Displays vesion and author of this script') do |v|
	options.version = "Sensu maintenance script for Zenoss / Sensu Plugin.\nVersion: 0.0.1\nAuthor: Augustyn Chmiel\nemail: augustyc@ie.ibm.com"
  end

  opt.on_tail('--help', 'Displays help') do
	  print opt
	  exit
  end


  if ARGV.length == 0
        print opt
        exit
  end

  opt.parse!(ARGV)
  options

  puts "[DEBUG] :: #{options}"
  if !options.version.nil?
	puts options.version
        exit
  end

  if options.pod.nil? && options.server.nil?
	options.pod = verify_pod(pod_dir)
  end

  if ((options.pod.nil? && options.server.nil?) || (!options.pod.nil? && !options.server.nil?))
        print opt
        exit
  end

  if ((options.status.nil? && options.prod.nil? && options.mtc.nil? && options.alerts.nil?) || (!options.status.nil? && !options.prod.nil? && !options.mtc.nil? && !options.alerts.nil?))
        print opt
        exit
  end

end

### Sensu API calls for: all silenced clients under DC
### Alerts in CRITICAL state, Calls to silence and unsilence the client checks

class SensuSilenced

	@@proto='http://'
	@@port=4567
	@@silenced='/silenced'
	@@headers={"Content-Type" => "application/json"}
	@@body=JSON['{}']


	def initialize(host)
		@host=host
		@url="#{@@proto}#{@host}:#{@@port}#{@@silenced}"
	end

	def get_silenced_status()
		r=HTTParty.get(@url)
		check=check_responce(r)
		if check.nil?
			translate_results(r)
		end
	end

	def check_responce(r, *message)
		unless r.success?
                        case r.code
			when 500
				puts "Error: 500 (Internal Server Error) for #{@host}"
			when 400
				puts "Malformed: 400 (Bad Request)"
			when 404
				if message.empty?
					puts "Missing: 404 (Not Found)"
				else
					puts message
                    return message
				end
			end
		else
			return nil
        end
	end

	def translate_results(r, *message)
		unless r.parsed_response.nil?
			json_h=JSON.parse(r.parsed_response.to_json)
			if json_h.kind_of?(Array)
				json_h.each do |i|
					if i['id'].include?('client:')
					    print "#{i['id'].split(':')[1]} \t: Current State:  Maintenance\n"
                    end
				end
			else
				print "#{json_h['id'].split(':')[1]} \t: Current State:  Maintenance\n"
			end
		else
			puts message
		end
	end

end

class SensuSilencedClientStatus < SensuSilenced

	@@client="/ids/client:"

	def get_client_status(client)
#puts "#{@url}#{@@client}#{client}:*"
        r=HTTParty.get("#{@url}#{@@client}#{client}:*")
		check=check_responce(r, "#{client} \t: Current State:  Production")
		if check.nil?
           translate_results(r)
        end
    end
end

class SensuSilencedClientClear < SensuSilenced

	@@clear='/clear'

	def clear_client_silence(client)
		@@body['id']="client:#{client}:*"
		r=HTTParty.post("#{@url}#{@@clear}", :headers => @@headers, :body => @@body.to_json)
		check=check_responce(r,"#{client} \t: Current State:  Production")
		if check.nil?
             translate_results(r, "#{client} \t: Current State:  Production")
        end
	end

end

class SensuSilenceClient < SensuSilenced

	def set_silenced_status(client)
		@@body['subscription']="client:#{client}"
        r=HTTParty.post(@url, :headers => @@headers, :body => @@body.to_json)
        check=check_responce(r)
		if check.nil?
             translate_results(r, "#{client} \t: Current State:  Maintenance")
        end
	end
end

class SensuClientAlerts < SensuSilenced

        @@results="/results"

	def initialize(host)
		@host=host
                @url="#{@@proto}#{@host}:#{@@port}#{@@results}"
	end

	def get_critical_alerts(client)
                r=HTTParty.get("#{@url}/#{client}")
                check=check_responce(r)
		json_h=JSON.parse(r.parsed_response.to_json)
		if json_h.kind_of?(Array)
                         json_h.each do |i|
				if i['check']['status'] > 0
					if i['check']['output'].include?("CRITICAL")
						@critical=i['check']['output']
					end
				end
		  	 end
		end
		unless @critical.nil? || @critical.empty? || !check.nil?
			puts "#{client} \t: CRITICAL Events:\n#{@critical}"
		else
			puts "#{client} \t: Status Healthy."
		end
        end
end

### Execution
###

puts "[DEBUG]:: 1 - Pod = [#{options.pod}] : server = [#{options.server}]"
if !options.pod.nil? && options.server.nil?
	mypod=mypod_servers(options.pod)
	sensu=get_sensu_server(mypod[0])
#    puts "sensu: #{sensu.to_str}"

	if options.status
		mypod.each do |x|
			SensuSilencedClientStatus.new(sensu).get_client_status(x)
		end
	end

	if options.mtc
		mypod.each do |x|
                	SensuSilenceClient.new(sensu).set_silenced_status(x)
		end
    end

    if options.prod
		mypod.each do |x|
                	SensuSilencedClientClear.new(sensu).clear_client_silence(x)
		end
    end

    if options.alerts
		mypod.each do |x|
                	SensuClientAlerts.new(sensu).get_critical_alerts(x)
		end
    end
end

puts "[DEBUG]:: 2 - Server = [#{options.server}] : server = [#{options.pod}]"
if !options.server.nil? && options.pod.nil?
	sensu=get_sensu_server(options.server)
    puts "sensu: #{sensu.to_str}"

    if options.status
    puts "status: #{options.status}"
        SensuSilencedClientStatus.new(sensu).get_client_status(options.server)
    end

	if options.mtc
    puts "mtc: #{options.mtc}"
		SensuSilenceClient.new(sensu).set_silenced_status(options.server)
	end

	if options.prod
    puts "prod: #{options.mtc}"
		SensuSilencedClientClear.new(sensu).clear_client_silence(options.server)
	end

	if options.alerts
		SensuClientAlerts.new(sensu).get_critical_alerts(options.server)
	end
end