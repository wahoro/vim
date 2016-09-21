"======================================================================
"
" tweak.vim - set transparency of gvim on windows
" python + vimscript implementation of vimtweak (script id 687)
"
" using ctypes module to get rid of the vimtweak.dll
" only require your gvim supporting python
"
" Created by skywind on 2016/09/21
" Last change: 2016/09/21 03:49:56
"
" Set gvim window transparency (0-255):
"     :TweakSetAlpha [alpha]
" 
" Enable gvim window top most:
"     :TweakEnableTopMost
"
" Disable gvim window top most:
"     :TweakEnableTopMost!
"
" Enable gvim window maximize:
"     :TweakEnableMaximize
"
" Disable gvim window maximize:
"     :TweakEnableMaximize!
"
" Enable gvim window caption:
"     :TweakEnableCaption
"
" Disable gvim window maximize:
"     :TweakEnableCaption!
"
"======================================================================
if (!has('python')) || (!(has('win32') || has('win64')))
	finish
endif


python << __EOF__

#----------------------------------------------------------------------
# Win32API
#----------------------------------------------------------------------
class Win32API (object):

	def __init__ (self):
		import ctypes
		self.kernel32 = ctypes.windll.LoadLibrary('kernel32.dll')
		self.user32 = ctypes.windll.LoadLibrary('user32.dll')
		self._query_interface()

	def _query_interface (self):
		import ctypes
		import ctypes.wintypes
		wintypes = ctypes.wintypes
		HWND, LONG, BOOL = wintypes.HWND, wintypes.LONG, wintypes.BOOL
		UINT, DWORD, c_int = wintypes.UINT, wintypes.DWORD, ctypes.c_int
		WPARAM, LPARAM = wintypes.WPARAM, wintypes.LPARAM
		self.WNDENUMPROC = ctypes.WINFUNCTYPE(
				wintypes.BOOL,
				wintypes.HWND,    # _In_ hWnd
				wintypes.LPARAM,) # _In_ lParam
		self.user32.EnumThreadWindows.argtypes = (
				wintypes.DWORD,
				self.WNDENUMPROC,
				wintypes.LPARAM)
		self.user32.EnumThreadWindows.restype = wintypes.BOOL
		self.user32.GetParent.argtypes = (wintypes.HWND,)
		self.user32.GetParent.restype = wintypes.HWND
		self.kernel32.GetConsoleWindow.argtypes = []
		self.kernel32.GetConsoleWindow.restype = wintypes.HWND
		self.user32.GetWindowLongA.argtypes = (HWND, ctypes.c_int)
		self.user32.GetWindowLongA.restype = LONG
		self.user32.SetWindowLongA.argtypes = (HWND, ctypes.c_int, LONG)
		self.user32.SetWindowLongA.restype = LONG
		self.kernel32.GetCurrentThreadId.argtypes = []
		self.kernel32.GetCurrentThreadId.restype = wintypes.DWORD
		self.user32.SendMessageA.argtypes = (HWND, UINT, WPARAM, LPARAM)
		self.user32.SendMessageA.restype = wintypes.LONG
		args = (HWND, HWND, c_int, c_int, c_int, c_int, UINT)
		self.user32.SetWindowPos.argtypes = args
		self.user32.SetWindowPos.restype = LONG
		args = (HWND, wintypes.COLORREF, wintypes.BYTE, DWORD)
		self.user32.SetLayeredWindowAttributes.argtypes = args
		self.user32.SetLayeredWindowAttributes.restype = BOOL

	def EnumThreadWindows (self, id, proc, lparam):
		return self.user32.EnumThreadWindows(id, proc, lparam)

	def GetWindowLong (self, hwnd, index):
		return self.user32.GetWindowLongA(hwnd, index)

	def SetWindowLong (self, hwnd, index, value):
		return self.user32.SetWindowLongA(hwnd, index, value)

	def GetCurrentThreadId (self):
		return self.kernel32.GetCurrentThreadId()

	def GetConsoleWindow (self):
		return self.kernel32.GetConsoleWindow()

	def GetParent (self, hwnd):
		return self.user32.GetParent(hwnd)

	def SendMessage (self, hwnd, msg, wparam, lparam):
		return self.user32.SendMessageA(hwnd, msg, wparam, lparam)

	def SetWindowPos (self, hwnd, after, x, y, cx, cy, flags):
		return self.user32.SetWindowPos(hwnd, after, x, y, cx, cy, flags)

	def SetLayeredWindowAttributes (self, hwnd, cc, alpha, flag):
		return self.user32.SetLayeredWindowAttributes(hwnd, cc, alpha, flag)


#----------------------------------------------------------------------
# VimTweak
#----------------------------------------------------------------------
class VimTweak (object):

	def __init__ (self):
		self.win32 = Win32API()
		self.__setup()

	def __setup (self):
		def FindWindowProc (hwnd, lparam):
			if self.win32.GetParent(hwnd):
				self.__save_hwnd = None
				return True
			self.__save_hwnd = hwnd
			return False
		FindWindowProc = self.win32.WNDENUMPROC(FindWindowProc)
		self.__ConsoleWindow = self.win32.GetConsoleWindow()
		if self.__ConsoleWindow:
			self.__TopWindow = self.__ConsoleWindow
		else:
			id = self.win32.GetCurrentThreadId()
			self.__save_hwnd = None
			self.win32.EnumThreadWindows(id, FindWindowProc, 1234)
			self.__TopWindow = self.__save_hwnd
		return 0

	def GetVimWindow (self):
		return self.__TopWindow

	def SetAlpha (self, alpha):
		GWL_EXSTYLE = -20
		WS_EX_LAYERED = 0x80000
		LWA_ALPHA = 2
		hwnd = self.GetVimWindow()
		if not hwnd:
			return -1
		alpha = int(alpha)
		if alpha >= 255:
			style = self.win32.GetWindowLong(hwnd, GWL_EXSTYLE)
			style = style & (~WS_EX_LAYERED)
			self.win32.SetWindowLong(hwnd, GWL_EXSTYLE, style)
		else:
			style = self.win32.GetWindowLong(hwnd, GWL_EXSTYLE)
			style = style | WS_EX_LAYERED
			self.win32.SetWindowLong(hwnd, GWL_EXSTYLE, style)
			self.win32.SetLayeredWindowAttributes(hwnd, 0, alpha, LWA_ALPHA)
		return 0

	def EnableCaption (self, enable):
		hwnd = self.GetVimWindow()
		if not hwnd:
			return -1
		GWL_STYLE = -16
		WS_CAPTION = 0xc00000
		enable = int(enable)
		if not enable:
			style = self.win32.GetWindowLong(hwnd, GWL_STYLE)
			self.win32.SetWindowLong(hwnd, GWL_STYLE, style & (~WS_CAPTION))
		else:
			style = self.win32.GetWindowLong(hwnd, GWL_STYLE)
			self.win32.SetWindowLong(hwnd, GWL_STYLE, style | WS_CAPTION)
		return 0

	def EnableMaximize (self, enable):
		hwnd = self.GetVimWindow()
		if not hwnd:
			return -1
		WM_SYSCOMMAND = 274
		SC_RESTORE = 0xF120
		SC_MAXIMIZE = 0xF030
		enable = int(enable)
		if not enable:
			self.win32.SendMessage(hwnd, WM_SYSCOMMAND, SC_RESTORE, 0)
		else:
			self.win32.SendMessage(hwnd, WM_SYSCOMMAND, SC_MAXIMIZE, 0)
		return 0

	def EnableTopMost (self, enable):
		hwnd = self.GetVimWindow()
		if not hwnd:
			return -1
		HWND_NOTOPMOST = -2
		HWND_TOPMOST = -1
		SWP_NOSIZE = 1
		SWP_NOMOVE = 2
		enable = int(enable)
		if not enable:
			self.win32.SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
					SWP_NOSIZE | SWP_NOMOVE)
		else:
			self.win32.SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0,
					SWP_NOSIZE | SWP_NOMOVE)
		return 0



#----------------------------------------------------------------------
# GetInstance - for lazy initialize ctypes
#----------------------------------------------------------------------
_VimTweakInstance = None

def VimTweakGetInstance():
	global _VimTweakInstance
	if _VimTweakInstance:
		return _VimTweakInstance
	_VimTweakInstance = VimTweak()
	return _VimTweakInstance

__EOF__

let g:tweak_alpha = 255

function! s:SetAlpha(alpha)
	python import vim
	python tweak = VimTweakGetInstance()
	python tweak.SetAlpha(vim.eval('a:alpha'))
	let g:tweak_alpha = 0 + a:alpha
endfunc

function! s:EnableCaption(enable)
	let l:enable = 1
	if a:enable == '!' || a:enable == 0
		let l:enable = 0
	endif
	python import vim
	python tweak = VimTweakGetInstance()
	python tweak.EnableCaption(vim.eval('l:enable'))
endfunc

function! s:EnableMaximize(enable)
	let l:enable = 0
	if a:enable == '' || a:enable != 0
		let l:enable = 1
	endif
	python import vim
	python tweak = VimTweakGetInstance()
	python tweak.EnableMaximize(vim.eval('l:enable'))
endfunc

function! s:EnableTopMost(enable)
	let l:enable = 0
	if a:enable == '' || a:enable != 0
		let l:enable = 1
	endif
	python import vim
	python tweak = VimTweakGetInstance()
	python tweak.EnableTopMost(vim.eval('l:enable'))
endfunc



"----------------------------------------------------------------------
" Command definition
"----------------------------------------------------------------------
command! -nargs=1 TweakSetAlpha call s:SetAlpha(0 + <args>)
command! -bang TweakEnableMaximize call s:EnableMaximize('<bang>')
command! -bang TweakEnableTopMost call s:EnableTopMost('<bang>')
command! -bang TweakEnableCaption call s:EnableTopMost('<bang>')





