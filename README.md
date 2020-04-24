# rails_json_serializer
A Rails gem that supports nested automatic eager-loading on assocations (via includes) and also supports Rails caching.
It utilizes the Rails `as_json` method, with the JSON queries building the `as_json` options.
It will inject the serializer methods into your classes.

Tested on Rails (5.2.2)

```
# Add to Gemfile
gem 'rails_json_serializer'
```

create init file: `config/initializers/serializer.rb`
and populate it with the following:
```
require "serializer"

# default values shown
Serializer.configure do |config|
  config.enable_includes = true
  config.default_cache_time = 360 # minutes
  # You can disable caching at the serializer level by leaving out the `cache_key` or setting `cache_for: nil`
  # You can also specify a different caching time using `cache_for`
  config.disable_model_caching = false
  config.debug = false
end
```

Now you can create folder and start adding your serializer files in it: `app/serializers`

Ex 1. If you have a User class, you can then create the file `app/serializers/user_serializer.rb` and populate it with the following:
```
module UserSerializer
  include ApplicationSerializer

  # This method will automatically be included in the module, but you can override it here.
  def serializer_query options = {}
    {
      :include => {
      },
      :methods => %w(),
      cache_key: __callee__,
    }
  end
end
```
Your User class will then have access to the class method: `User.serializer`, the instance method `User.first.serializer`, and also access to the query method: `User.serializer_query`

Ex 2.
```
module UserSerializer
  include ApplicationSerializer

  def serializer_query options = {}
    {
      :include => {
        :friends => User.tiny_serializer_query.merge({as: :friends_attributes}),
      },
      :methods => %w(),
      cache_key: __callee__,
    }
  end
  
  def tiny_serializer_query options = {}
    {
      cache_key: __callee__,
    }
  end
end
```
We've updated the Rails `as_json` method to support aliasing via the `:as` key.
In addition to the User object having the class and instance `serializer` method, it will now also have the `tiny_serializer` methods as well.

Can optionally use a `skip_serializer_includes` option on serializers to skip eagerloading.
`User.first.serializer({skip_includes: true})`
or 
`User.serializer({skip_includes: true})`

Or define it at the JSON query level:
```
module UserSerializer
  include ApplicationSerializer
  def serializer_query options = {}
    {
      :include => {
        :friends => User.serializer_query.merge({as: :friends_attributes}),
      },
      :methods => %w(),
      cache_key: __callee__,
      cache_for: nil,
      skip_includes: true
    }
  end
end
```
