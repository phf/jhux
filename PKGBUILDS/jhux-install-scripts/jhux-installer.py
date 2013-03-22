#! /usr/bin/env python2

try:
	from gi.repository import Gtk, GLib, Gdk
	GLib.threads_init()
	pygtk=False
except:
	import gtk as Gtk
	from gtk import gdk as Gdk
	pygtk=True
import os, sys, subprocess, time, threading, Queue

Gdk.threads_init()

class AsyncInstaller(threading.Thread):
	def __init__(self, iw, steps, iter):
		threading.Thread.__init__(self)
		self._iw = iw
		self._steps = steps
		self._iter = iter

	def run(self):
		steps_done = 0
		iter = self._iter
		for step in self._steps:
			Gdk.threads_enter()
			self._iw.status_label.set_text(step['label'])
			Gdk.threads_leave()
			proc = subprocess.Popen(" ".join(step['cmd']), shell=True, stdout=subprocess.PIPE)
			stdout_q = Queue.Queue()
			stdout_r = AsyncOutputReader(proc.stdout, stdout_q)
			stdout_r.start()
			while not stdout_r.eof():
				while not stdout_q.empty():
					line = stdout_q.get()
					Gdk.threads_enter()
					self._iw._textbuffer.insert(iter, line, -1)
					Gdk.threads_leave()
				time.sleep(0.1)
			stdout_r.join()
			proc.stdout.close()
			steps_done = steps_done + 1
			Gdk.threads_enter()
			self._iw.progressbar.set_fraction((steps_done + 0.0) / len(self._steps))
			Gdk.threads_leave()

class AsyncOutputReader(threading.Thread):
	def __init__(self, fd, queue):
		threading.Thread.__init__(self)
		self._fd = fd
		self._queue = queue

	def run(self):
		for line in iter(self._fd.readline, ''):
			self._queue.put(line)

	def eof(self):
		return not self.is_alive() and self._queue.empty()

class InstallWindow:
	def __init__ (self):
		if pygtk:
			gui = Gtk.Builder()
		else:
			gui = Gtk.Builder.new()
		gui.add_from_file("/usr/share/jhux-installer/jhux-install.xml")
		win = gui.get_object("window1")
		win.set_title("JH/UX Installer")
		win.show_all()
		win.connect("destroy", self.destroy)
		b_cancel = gui.get_object("button1")
		b_install = gui.get_object("button2")
		b_cancel.connect("clicked", self.destroy)
		b_install.connect("clicked", self.install)
		self.partition = gui.get_object("entry1")
		self.hostname = gui.get_object("entry2")
		self.username = gui.get_object("entry3")
		self.password = gui.get_object("entry4")
		self.grubdev = gui.get_object("entry6")
		self.progressbar = gui.get_object("progressbar1")
		self.status_label = gui.get_object("label7")
		textview = gui.get_object("textview1")
		self._textbuffer = textview.get_buffer()
	
	def install (self, widget, data=None):
		global installthread
		"""active = manager_prop_iface.Get("org.freedesktop.NetworkManager", "ActiveConnections")
		connected = False
		for a in active:
			ac_proxy = bus.get_object("org.freedesktop.NetworkManager", a)
			prop_iface = dbus.Interface(ac_proxy, "org.freedesktop.DBus.Properties")
			state = prop_iface.Get("org.freedesktop.NetworkManager.Connection.Active", "State")
			if state == 2:
				connected = True
		if not connected:
			print "Not connected to the internet...aborting!"
			return"""
		steps = [{"label": "Partitioning Disks...", "cmd": ['/usr/lib/jhux-installer/01_prepare_disks', self.partition.get_text()]},
			 {"label": "Installing Packages...", "cmd": ['/usr/lib/jhux-installer/02_install_packages']},
			 {"label": "Configuring System...", "cmd": ['/usr/lib/jhux-installer/03_configure_system', self.username.get_text(), self.password.get_text(), self.hostname.get_text(), self.grubdev.get_text()]}]
		installthread = AsyncInstaller(self, steps, self._textbuffer.get_start_iter())
		installthread.start()

	def destroy (self, widget, data=None):
		if installthread:
			installthread.join()
		Gtk.main_quit()

installthread = None

if __name__ == "__main__":
	installwin = InstallWindow()
	Gdk.threads_enter()
	Gtk.main()
	Gdk.threads_leave()
