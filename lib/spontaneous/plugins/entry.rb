# encoding: UTF-8

module Spontaneous::Plugins
  module Entry
    extend ActiveSupport::Concern

    # InstanceMethods

    # kept to allow access to pages & pieces as they would be seen when
    # accessed as an entry in a box
    def entry
      self
    end

    def box_sid
      @box_sid ||= Spontaneous.schema.uids[self[:box_sid]]
    end

    def box_sid=(sid)
      self[:box_sid] = sid.to_s
    end

    def box
      container.boxes.sid(box_sid) if container
    end

    def first?
      container.pieces.first == self
    end

    def last?
      container.pieces.last == self
    end

    def set_position(new_position)
      if box
        box.set_position(self, new_position)
      else
        container.pieces.set_position(self, new_position)
      end
    end

    def position
      return box.index(self) if box
      container.pieces.index(self)
    end

    def serialize_db
      [self.id]
    end
  end # Entry
end # Spontaneous::Plugins
