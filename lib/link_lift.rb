require 'net/http'
require 'rubygems'
require "rexml/document"
require 'tmpdir'
require 'active_support'
require 'thread'
require 'timeout'

class LinkLift
  
  class LinkLiftError < Exception ; end
  
  SERVER_HOST = 'external.linklift.net'
  PLUGIN_VERSION = '0.1'
  PLUGIN_DATE = '20080311'
  SEMAPHORE = Mutex.new
  
  if defined?(RAILS_ROOT) 
    TMP_DIR = RAILS_ROOT + '/public/'
  else
    TMP_DIR = "#{Dir.tmpdir}/"
  end

  attr_accessor :links

  def initialize(options = {})
    raise ArgumentError, 'Website key missing for linklift' if options[:website_key].blank?
    raise ArgumentError, 'Website plugin secret for linklift missing' if options[:plugin_secret].blank?
    
    @options = {
      :filename => nil,
      :timeout => 1, # in hours
      :show_test_link => false
    }.update(options)
    
    @links = read_links
    return self
  end
  
  def local_xml_file
    if @options[:filename]
      TMP_DIR + @options[:filename]
    else
      TMP_DIR + @options[:website_key] + '.xml'
    end
  end
  
  def necessary_to_load_new_file?
    not local_xml_file_current?
  end
    
  def local_xml_file_current?
    File.exists?(local_xml_file) && File.mtime(local_xml_file) > @options[:timeout].hours.ago
  end
  
  def read_links
    links = []

    data = nil
    SEMAPHORE.synchronize do
      if necessary_to_load_new_file?
        data = retrieve_links
      else
        data = File.read(local_xml_file)
      end
    end

    xml_feed = REXML::Document.new(data, :respect_whitespace => false)
    
    xml_feed.elements.each("ll_data/adspace/link/") do |link|  

      new_link = Link.new
      %w(text prefix postfix rss_url rss_text rss_prefix rss_postfix nofollow).each do |node_name|
        new_link.send("#{node_name}=", link.elements[node_name].text)
      end
      
      new_link.url = handle_url(link.elements['url'].text)
      
      links << new_link unless (test_link?(new_link) && !@options[:show_test_link])
    end
    return links
  rescue Object => e
    raise LinkLiftError, e.message, e.backtrace
  end
  
  def test_link?(link)
    link.url.match(@options[:plugin_secret])
  end

  def retrieve_links
    result = nil
    status = false
    status = Timeout::timeout(5) do
      result = Net::HTTP.get(SERVER_HOST, '/external/textlink_data.php5?' + {
        'website_key' => @options[:website_key],
        'linklift_secret' => @options[:plugin_secret],
        'plugin_language' => 'ruby',
        'plugin_date' => '20080311',
        'plugin_version' => VERSION,
        'plugin_creation_date' => '20080311',
        'condition_no_css' => 0,
        'condition_no_html_tags' => 0 }.collect{|a,b| [a,b].join('=')}.join('&')
        )
    end
    raise "Linklift timed out...." unless status
    
    update_local_xml_file(result)
    return result
  rescue Object => e
    raise LinkLiftError, e.message, e.backtrace
  end
  
  def update_local_xml_file(data)    
    # write the data to a temp file
    temp_file = "#{Dir.tmpdir}/link_lift_data_#{$$}.xml"
    File.open(temp_file, 'w+') do |f|
      f.flock File::LOCK_EX
      f << data
    end
    
    # swap the files
    FileUtils.mv(temp_file, local_xml_file)
  end
  
  def handle_url(broken_url)
    return broken_url.gsub(/" rel="nofollow\Z/, '')
  end
  
  class Link
    attr_accessor :url, :text, :prefix, :postfix, :rss_url, :rss_text, :rss_prefix, :rss_postfix, :nofollow
    
    def no_follow?
      self.nofollow.to_i == 1
    end
  end
end
