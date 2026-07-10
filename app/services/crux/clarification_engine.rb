module Crux
  # Given an intent + message text, returns either nil (enough information
  # already exists) or a small set of follow-up questions. Only
  # :create_project has documented clarification content (vision.md's HRMS
  # example) — no other worked example exists for the remaining 20 intents,
  # so they're treated as always-sufficient for this task's scope.
  class ClarificationEngine
    HRMS_QUESTIONS = [
      'Which technology stack?',
      'Expected delivery timeline?',
      'Authentication method?',
      'Database?',
      'Expected modules?',
      'Deployment environment?'
    ].freeze

    def self.call(intent:, conversation:, text:)
      return nil unless intent == :create_project

      if conversation.messages.where(role: 'agent').empty?
        return sufficient?(text) ? nil : HRMS_QUESTIONS
      end

      pending = HRMS_QUESTIONS[answered_count(conversation)..] || []
      pending.empty? ? nil : pending
    end

    # "Create a CRM System with Customer, Leads, and Invoice modules." names
    # its modules inline; "Create an HRMS." doesn't — presence of "with" plus
    # enough surrounding detail is this task's rule-based stand-in for
    # "the request already answers most of the HRMS question set."
    def self.sufficient?(text)
      text.to_s =~ /\bwith\b/i && text.to_s.strip.length > 20
    end

    # Counts how many of the 6 questions have been answered so far, treating
    # every user reply after the original request as one or more answers.
    # A reply is split on common delimiters so a single free-text message
    # that bundles several answers ("React, and 3 months") counts as
    # multiple answered questions, not just one.
    def self.answered_count(conversation)
      replies = conversation.messages.where(role: 'user').order(:created_at).offset(1)
      replies.to_a.sum do |message|
        segments = message.content.to_s.split(/,|;|\band\b|\n/i).map(&:strip).reject(&:empty?)
        segments.empty? ? 1 : segments.size
      end
    end
    private_class_method :sufficient?, :answered_count
  end
end
