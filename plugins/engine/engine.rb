author       'Daniel Mendler'
description  'Engine subsystem'

# Engine context
# A engine context holds the request parameters and other
# variables used by the engines.
# It is possible for a engine to run sub-engines. For this
# purpose you create a subcontext which inherits the variables.
class Wiki::Context < Struct.new(:app, :resource, :engine, :logger, :request,
                                 :response, :parent, :private, :params)
  include Hooks

  alias page resource
  alias tree resource

  def initialize(attrs = {})
    update(attrs)
    self.logger  ||= Logger.new(nil)
    self.params  ||= HashWithIndifferentAccess.new
    self.private ||= HashWithIndifferentAccess.new
    invoke_hook(:initialized)
  end

  def subcontext(attrs = {})
    attrs = to_hash.merge!(attrs)
    attrs[:params] = params.merge(attrs[:params] || {})
    attrs[:private] = private.merge(attrs[:private] || {})
    attrs[:parent] = self
    Context.new(attrs)
  end
end

# An Engine renders resources
# Engines get a resource as input and create text.
class Wiki::Engine
  include PageHelper
  include Templates

  @engines = {}

  # Constructor for engine
  # Options:
  # * layout: Engine output should be wrapped in HTML layout (Not used for download/image engines for example)
  # * cacheable: Engine output can be cached
  # * priority: Engine priority. The engine with the lowest priority will be used for a resource.
  def initialize(name, opts)
    @name = name.to_s
    @layout = !!opts[:layout]
    @cacheable = !!opts[:cacheable]
    @priority = (opts[:priority] || 99).to_i
  end

  attr_reader :name, :priority
  question_reader :layout, :cacheable

  # Create engine class. This is sugar to create and
  # register an engine class in one step.
  def self.create(name, opts = {}, &block)
    engine = Class.new(Engine)
    engine.class_eval(&block) if block
    register engine.new(name, opts)
  end

  # Register engine instance
  def self.register(engine)
    (@engines[engine.name] ||= []) << engine
  end

  # Find all accepting engines for a resource
  def self.find_all(resource)
    @engines.values.flatten.find_all { |e| e.accepts? resource }.sort_by {|a| a.name }
  end

  # Find appropiate engine for resource. An optional
  # name can be given to claim a specific engine.
  # If no engine is found a exception is raised.
  def self.find!(resource, opts = {})
    opts[:name] ||= resource.metadata[:output] || resource.metadata[:engine] if !resource.meta?
    engines = opts[:name] ? @engines[opts[:name].to_s] : @engines.values.flatten
    engine = engines.to_a.sort_by {|a| a.priority }.find { |e| e.accepts?(resource) && (!opts[:layout] || e.layout?) }
    raise(RuntimeError, :engine_not_available.t(:engine => opts[:name], :page => resource.path, :mime => resource.mime)) if !engine
    engine.dup
  end

  # Find appropiate engine for resource. An optional
  # name can be given to claim a specific engine.
  # If no engine is found nil is returned.
  def self.find(resource, opts = {})
    find!(resource, opts) rescue nil
  end

  # Acceptor should return true if resource would be accepted by this engine.
  # Reimplement this method.
  def accepts?(resource); resource.respond_to? :content; end

  # Render resource content.
  # Reimplement this method.
  def output(context); context.resource.content; end

  # Get output mime type.
  # Reimplement this method.
  def mime(resource); resource.mime; end

  # Render resource with possible caching. It should not be overwritten.
  def render(context)
    context.engine = self
    output(context)
  end
end

# Plug-in the engine subsystem
class Wiki::Application
  hook(:before_resource_show) do
    @context = Context.new(:app => self,
                           :resource => @resource,
                           :params => params,
                           :request => request,
                           :response => response,
                           :logger => logger)
    @engine = Engine.find!(@resource, :name => params[:output] || params[:engine])
    @content = @engine.render(@context)
    if @engine.layout?
      halt haml(:show)
    else
      content_type @engine.mime(@resource).to_s
      halt @content
    end
  end

  hook(:after_view_menu) do
    haml :engines_menu, :layout => false
  end
end
