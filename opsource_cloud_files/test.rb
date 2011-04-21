require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../opsource_cloud_files.rb', __FILE__)

class OpSourceCloudFilesTest < Test::Unit::TestCase
  def setup
    @plugin = OpSourceCloudFiles.new(
      nil, memory = {}, 
      :username => 'my_user', :password => 'my_password'
    )
    @uri = "https://my_user:my_password@cf-na-east-01.opsourcecloud.net/v2/account"
  end                            
    
  def test_should_load_storage_info                      
    FakeWeb.register_uri(:get, @uri, :body => stub_response)           

    result = @plugin.run                                           

    report = result[:reports].first
    assert_equal 4, report[:storage_allocated]
    assert_equal 2, report[:storage_used]      
    assert_equal 50, report[:storage_percent_used]
  end
    
  def test_should_load_bandwidth_info
    FakeWeb.register_uri(:get, @uri, :body => stub_response)           

    result = @plugin.run                                           
    
    report = result[:reports].first
    assert_equal 4, report[:bandwidth_allocated]
    assert_equal 2, report[:bandwidth_total]      
    assert_equal 9.5367431640625e-07, report[:bandwidth_private]
    assert_equal 9.5367431640625e-07, report[:bandwidth_public]
    assert_equal 50, report[:bandwidth_percent_used]
  end
    
  def test_should_return_ceiling_for_percent_used
    FakeWeb.register_uri(:get, @uri, :body => stub_response(0.755))    

    result = @plugin.run                                           
    
    report = result[:reports].first
    assert_equal 76, report[:bandwidth_percent_used]
    assert_equal 76, report[:storage_percent_used]
  end     
  
  private 
  def stub_response(used_ratio = 0.5)
    allocated = 1024**2 * 4
    used = used_ratio * allocated
    <<-EOR
    <?xml version="1.0"?>
    <account-info xmlns:xlink="http://www.w3.org/1999/xlink">
      <username>my_user</username>
      <storage>
        <allocated>#{allocated}</allocated>
        <used>#{used}</used>
      </storage>
      <bandwidth>
        <allocated>#{allocated}</allocated>
        <total>#{used}</total>
        <private>1</private>
        <public>1</public>
      </bandwidth>
    </account-info>
    EOR
  end
end