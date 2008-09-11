require 'test/unit'
require 'link_lift'
require 'mocha'
require 'active_support'

# test the break_to_fit function
class LinkLiftTest < Test::Unit::TestCase

  if defined?(RAILS_ROOT) 
    TMP_PATH = "#{RAILS_ROOT}/public/"
  else
    TMP_PATH = "#{Dir.tmpdir}"
  end

  def setup
    @expected_link_lift_result = File.read("#{File.dirname(__FILE__)}/link_lift_result.xml")
    @expected_link_lift_result_complex = File.read("#{File.dirname(__FILE__)}/link_lift_result_complex.xml")

    Dir.glob("#{TMP_PATH}/*.xml").each do |f|
      FileUtils.rm f
    end
  end
  
  def teardown
    LinkLift.reset_last_xml_update
  end

  def test_validations
    assert_raise(ArgumentError) do
      LinkLift.new
    end
    
    assert_raise(ArgumentError) do
      LinkLift.new(:website_key => nil)
    end
    
    assert_raise(ArgumentError) do
      LinkLift.new(:website_key => '')
    end
    
    assert_raise(ArgumentError) do
      LinkLift.new(:website_key => 'foo')
    end
    
    assert_raise(ArgumentError) do
      LinkLift.new(:website_key => 'foo', :plugin_secret => nil)
    end
    
    assert_raise(ArgumentError) do
      LinkLift.new(:website_key => 'foo', :plugin_secret => '')
    end
  end
  
  def test_validations_with_good_credentials
    Net::HTTP.expects(:get).returns(@expected_link_lift_result)
    
    assert_nothing_raised do
      LinkLift.new(:website_key => 'foo', :plugin_secret => 'bar')
    end
  end

  def test_exception_handling
    Net::HTTP.expects(:get).raises(RuntimeError)
    
    assert_raise(LinkLift::LinkLiftError) do
      l = LinkLift.new(:website_key => 'foo', :plugin_secret => 'bar')
    end
  end
  
  def test_parse_url
    Net::HTTP.expects(:get).returns(@expected_link_lift_result)
    
    l = LinkLift.new(:website_key => 'foo', :plugin_secret => 'bar')
    
    expected_links = ['http://www.foobar.org']
    assert_equal expected_links.sort, l.links.map(&:url).sort
  end
  
  def test_custom_filename
    Net::HTTP.expects(:get).returns(@expected_link_lift_result)
    l = LinkLift.new(:website_key => 'foo', :plugin_secret => 'bar', :filename => 'dr.metschke.xml')
    assert_equal "#{TMP_PATH}/dr.metschke.xml", l.local_xml_file
  end
  
  def test_complex_link_lift_result
     Net::HTTP.expects(:get).returns(@expected_link_lift_result_complex)

      l = LinkLift.new(:website_key => 'foo', :plugin_secret => 'bar')

      expected_links = ["http://www.headcrash.net",
       "http://www.kredit-engel.de",
       "http://www.magistrix.de",
       "http://www.poplexikon.com",
       "http://www.ready2host.de/SSL-Zertifikate"]
      assert_equal expected_links.sort, l.links.map(&:url).sort
  end
  
  def test_update_of_inmemory_timestamp_of_last_update
    Net::HTTP.expects(:get).returns(@expected_link_lift_result_complex).times(1)
    Time.stubs(:now).returns(Time.local(2008, 9, 28))
    
    l = LinkLift.new(:website_key => 'foo', :plugin_secret => 'bar')
    assert_equal Time.local(2008, 9, 28), LinkLift.last_xml_update
    
    # now create another LinkLift instance - this one should not call Net::HTTP
    other = LinkLift.new(:website_key => 'foo', :plugin_secret => 'bar')
  end


end