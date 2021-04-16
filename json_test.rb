#!/usr/local/opt/ruby/bin/ruby
# -*- coding: UTF-8 -*-
require 'httparty' ;
require 'json'
require 'optparse'
require 'ostruct'


def got_success?(success)

    unless success.success?
            puts "Sous Chef instance returned #{success.code}"
            exit
    end
end

def verify_pod(_pod)
        puts "[DEBUG] :: <verify_pod(_pod)> _pod = [#{_pod}]"
	v=HTTParty.get("http://souschef.atlis1/sc/d/pod2bgservers?iter&sort")
	got_success?(v)
    pods = JSON.load(v.body)

#	pods=v.body.split("\n")
	pods.each do |pod|
                pod = pod.delete('", ')
                puts "[DEBUG] :: <verify_pod(_pod)> _pod = [#{_pod}] == pod = [#{pod}]"
		if pod.downcase.eql?(_pod.downcase)
			return pod
		end
	end
	return nil
end

def get_sensu_server(server_name)
    sensu_list = Hash.new ;
    get_sensu=HTTParty.get("http://souschef.atlis1/sc/d/prod?iter&sort")

    got_success?(get_sensu)

    servers_prod=get_sensu.body.split("\n")
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
            return sensu
    elsif server_name.include?("adm01.com")
            sensu=sensu_list[server_name.split('-')[0]]
            if sensu.nil?
                sensu='vsensu02.atlis1'
            end
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
            return sensu
    else
            sensu=sensu_list[server_name.split('.')[1]]
            if sensu.nil?
                sensu='vsensu02.atlis1'
            end
            return sensu
    end
    puts sensu
end


def mypod_servers(_pod)
    get_apps=HTTParty.get("http://souschef.atlis1/sc/d/pod2appservers/#{_pod}?iter&sort=desc")
    get_bgs=HTTParty.get("http://souschef.atlis1/sc/d/pod2bgservers/#{_pod}?iter&sort=desc")

    got_success?(get_apps)
    got_success?(get_bgs)

#    apps = get_apps.body.split("\n")
#    bgs = get_bgs.body.split("\n")

    apps = JSON.load(get_apps.body)
    bgs = JSON.load(get_bgs.body)

    apps.concat(bgs)
    return apps
end

#puts get_sensu_server

#puts "- #{verify_pod('pod1')} -"
puts "- #{mypod_servers('pod1')} -"

