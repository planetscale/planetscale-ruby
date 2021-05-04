# frozen_string_literal: true

module Planetscale
  TAG = ENV.fetch("SHORT_SHA", "x")
  VERSION = '0.6.0.' + TAG
end
