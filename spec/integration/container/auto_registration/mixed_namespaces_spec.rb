RSpec.describe "Auto-registration / Components with mixed namespaces" do
  before do
    class Test::Container < Dry::System::Container
      configure do |config|
        config.root = SPEC_ROOT.join("fixtures/mixed_namespaces").realpath

        config.component_dirs.add "lib" do |dir|
          dir.default_namespace = "my_app"
        end
      end
    end
  end

  it "loads components with and without the default namespace (lazy loading)" do
    expect(Test::Container["app_component"]).to be_an_instance_of MyApp::AppComponent
    expect(Test::Container["external.external_component"]).to be_an_instance_of External::ExternalComponent
  end

  it "loads components with and without the default namespace (finalizing)" do
    Test::Container.finalize!

    expect(Test::Container["app_component"]).to be_an_instance_of MyApp::AppComponent
    expect(Test::Container["external.external_component"]).to be_an_instance_of External::ExternalComponent
  end
end
