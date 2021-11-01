local CancellableJob = {}
CancellableJob.__index = CancellableJob

function CancellableJob.new(opts)
   if not opts then
      error("Options are required for CancellableJob")
   end
   local duration = opts.duration or 1000
   local on_run = opts.on_run or function() end
   local on_cancel = opts.on_cancel or function() end
    return setmetatable({ cancelled = false, duration = duration, on_run = on_run, on_cancel = on_cancel }, CancellableJob)
end

CancellableJob.start = function(self)
   if self.cancelled then
       return
    end
   local timer = vim.loop.new_timer()
   timer:start(self.duration, 0, function()
      timer:stop()
      timer:close()
      if self.cancelled then
         return
      end
      vim.schedule(function() self.on_run() end)
   end)
end

CancellableJob.cancel = function(self)
   self.cancelled = true
   self.on_cancel()
end

return CancellableJob
